import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';

enum AiProvider {
  openRouter,
  openAi,
}

class _BaoBaoCreditRange {
  final int? min;
  final int? max;

  const _BaoBaoCreditRange({
    required this.min,
    required this.max,
  });

  bool get hasTarget => min != null || max != null;

  @override
  String toString() {
    if (min == null && max == null) return 'no target';
    if (min != null && max != null && min != max) return '$min-$max credits';
    final value = min ?? max;
    return '$value credits';
  }
}

class BaoBaoCourseIntent {
  final String intent;
  final String basePlan;
  final List<Map<String, dynamic>> actions;
  final Map<String, dynamic>? memoryUpdate;
  final bool needsClarification;
  final String? clarifyingQuestion;
  final bool usePreviousRecommendation;
  final String searchMode;
  final String query;

  const BaoBaoCourseIntent({
    required this.intent,
    required this.basePlan,
    required this.actions,
    required this.memoryUpdate,
    required this.needsClarification,
    required this.clarifyingQuestion,
    this.usePreviousRecommendation = false,
    this.searchMode = 'unknown',
    this.query = '',
  });

  factory BaoBaoCourseIntent.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final parsedActions = <Map<String, dynamic>>[];

    if (rawActions is Iterable) {
      for (final item in rawActions) {
        if (item is Map) {
          parsedActions.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final rawMemory = json['memoryUpdate'];

    return BaoBaoCourseIntent(
      intent: (json['intent'] ?? 'new_plan').toString(),
      basePlan: (json['basePlan'] ?? 'none').toString(),
      actions: parsedActions,
      memoryUpdate: rawMemory is Map
          ? Map<String, dynamic>.from(rawMemory)
          : null,
      needsClarification: json['needsClarification'] == true,
      clarifyingQuestion: json['clarifyingQuestion']?.toString(),
      usePreviousRecommendation: json['usePreviousRecommendation'] == true,
      searchMode: (json['searchMode'] ?? 'unknown').toString(),
      query: (json['query'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'basePlan': basePlan,
      'actions': actions,
      'memoryUpdate': memoryUpdate,
      'needsClarification': needsClarification,
      'clarifyingQuestion': clarifyingQuestion,
      'usePreviousRecommendation': usePreviousRecommendation,
      'searchMode': searchMode,
      'query': query,
    };
  }

  bool get isModifyPreviousPlan => intent == 'modify_previous_plan';
  bool get isDirectSearch => intent == 'direct_search';
  bool get isMemoryUpdate => intent == 'memory_update';
  bool get isClearMemory => intent == 'clear_memory';
  bool get isClarificationNeeded =>
      needsClarification || intent == 'clarification_needed';
  bool get isSmallTalk => intent == 'small_talk';

  List<String> get avoidKeywords {
    final value = memoryUpdate?['avoidKeywords'];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> get preferredKeywords {
    final value = memoryUpdate?['preferredKeywords'];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  String toString() => toJson().toString();
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
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('baoBaoOpenAiChat');

      final result = await callable.call({
        'systemPrompt': systemPrompt,
        'userContent': userContent,
        'temperature': temperature,
        'maxTokens': maxTokens,
      });

      final data = result.data;

      if (data is Map) {
        final content = data['content']?.toString().trim();
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }

      return null;
    } catch (error) {
      print('Bao-Bao Firebase OpenAI call failed: $error');
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


  Future<Map<String, dynamic>> buildBaoBaoPreferenceSearchProfile({
    required Map<String, dynamic>? userPreferences,
  }) async {
    final prefs = _preferenceMap(userPreferences);

    if (prefs.isEmpty) {
      return {};
    }

    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's academic preference resolver.

Return JSON only. No markdown. Do not recommend course IDs.

Your job is to translate ANY student's preference profile into flexible course-search hints.
Use reasoning from the career path, department/program, GE interests, language preference, target credits, and requested core-course count.
Do not use fixed if/else career mappings.
Do not force GE interests to dominate career planning when careerPaths exists.

Schema:
{
  "careerKeywords": [],
  "departmentKeywords": [],
  "coreCourseHints": [],
  "electiveHints": [],
  "geHints": [],
  "avoidKeywords": [],
  "planningNotes": []
}

Rules:
- careerKeywords should be academic topics related to the career path.
- departmentKeywords should include department/program vocabulary if available.
- coreCourseHints should be foundational or required-style course topics useful for that career/department.
- electiveHints should be supporting or advanced topics useful for that career.
- geHints should come from GE interests only.
- avoidKeywords should contain courses/topics that clearly conflict with the profile.
- Keep every keyword short and searchable in course title, department, remarks, or metadata.
- Prefer academic course-topic words over job titles.
- If careerPaths exists, career/core/elective hints should be more important than GE hints.
- If the latest user prompt explicitly asks for an academic area, that area becomes the main target. Do not replace it with the user’s saved department or career path. Use the user profile only to choose better courses inside or near that requested area.
- If the user requests a number of core courses, planningNotes should mention it.
''',
      userContent: jsonEncode(_jsonSafe({
        'userPreferences': prefs,
      })),
      temperature: 0.04,
      maxTokens: 700,
    );

    if (content == null || content.trim().isEmpty) {
      return {};
    }

    try {
      final parsed = jsonDecode(_extractJsonObject(content));

      if (parsed is! Map) {
        return {};
      }

      final profile = Map<String, dynamic>.from(parsed);

      print('Bao-Bao AI preference search profile: $profile');

      return profile;
    } catch (error) {
      print('Bao-Bao preference profile parse failed: $error');
      print('Bao-Bao raw preference profile AI response: $content');

      // Some OpenRouter free models answer with prose or truncated text even
      // when we ask for JSON. Repair once instead of silently losing the
      // AI-generated preference understanding.
      final repaired = await _callAiChat(
        systemPrompt: '''
Return valid JSON only. No markdown.
Convert the user's text into this exact schema:
{
  "careerKeywords": [],
  "departmentKeywords": [],
  "coreCourseHints": [],
  "electiveHints": [],
  "geHints": [],
  "avoidKeywords": [],
  "planningNotes": []
}
Use empty arrays for missing fields.
''',
        userContent: content,
        temperature: 0.0,
        maxTokens: 500,
      );

      if (repaired == null || repaired.trim().isEmpty) {
        return {};
      }

      try {
        final parsed = jsonDecode(_extractJsonObject(repaired));
        return parsed is Map ? Map<String, dynamic>.from(parsed) : {};
      } catch (repairError) {
        print('Bao-Bao preference profile repair failed: $repairError');
        print('Bao-Bao repaired preference profile response: $repaired');
        return {};
      }
    }
  }

  Future<Map<String, dynamic>?> _withAiGeneratedPreferenceSearchProfile(
    Map<String, dynamic>? rawPreferences,
  ) async {
    if (rawPreferences == null) {
      return null;
    }

    final existingPrefs = _preferenceMap(rawPreferences);
    if (_searchProfileMap(existingPrefs).isNotEmpty) {
      return rawPreferences;
    }

    final profile = await buildBaoBaoPreferenceSearchProfile(
      userPreferences: rawPreferences,
    );

    if (profile.isEmpty) {
      return rawPreferences;
    }

    final copied = Map<String, dynamic>.from(rawPreferences);

    if (copied['preferences'] is Map) {
      final nested = Map<String, dynamic>.from(copied['preferences'] as Map);
      nested['baoBaoSearchProfile'] = profile;
      copied['preferences'] = nested;
    } else {
      copied['baoBaoSearchProfile'] = profile;
    }

    return copied;
  }


  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    // Firestore Timestamp cannot be encoded by jsonEncode directly.
    // Avoid importing cloud_firestore here just for a type check.
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        final dynamic timestamp = value;
        return timestamp.toDate().toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }

    if (value is List) {
      return value.map(_jsonSafe).toList();
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }

    return value.toString();
  }

  // ============================================================
  // INTENT RESOLVER: UNDERSTAND FOLLOW-UP / MEMORY / NEW PLAN
  // ============================================================

  Future<BaoBaoCourseIntent> understandBaoBaoCourseIntent({
    required String userMessage,
    required List<String> lastRecommendationIds,
    required List<String> plannedCourseIds,
    Map<String, dynamic>? userPreferences,
  }) async {
    // Prompt-first design:
    // Do not locally parse the user's words into a subject/professor/category.
    // Bao-Bao asks the model to understand the whole prompt and return a
    // structured decision. Local fallback is intentionally broad and safe.
    final promptFirstFallback = BaoBaoCourseIntent(
      intent: 'new_plan',
      basePlan: 'none',
      actions: const [],
      memoryUpdate: null,
      needsClarification: false,
      clarifyingQuestion: null,
      usePreviousRecommendation: false,
      searchMode: 'general_plan',
      query: userMessage.trim(),
    );

    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's intent resolver for an NTHU course planner app.

Return JSON only. No markdown. Do not recommend courses here.

Treat the student's entire message as a natural prompt, not as a keyword search.
Your job is to infer the student's real task and decide what the planner should do.
Do not hardcode particular professors, careers, course names, or examples as special cases.

Valid intents:
- direct_search
- new_plan
- modify_previous_plan
- memory_update
- clear_memory
- small_talk
- clarification_needed

Decision principles:
- direct_search = the request can be answered by searching real course metadata without using the previous recommendation.
- new_plan = the user describes a goal, direction, preference mix, semester style, or asks Bao-Bao to recommend a plan.
- modify_previous_plan = only when the user clearly wants to edit an existing/current/previous plan.
- clarification_needed = the user asks to add/change a broad category but Bao-Bao needs more detail before changing the plan safely.
- memory_update = only when the user clearly wants Bao-Bao to remember something for future requests.
- clear_memory = only when the user clearly asks to clear/reset/forget Bao-Bao memory.

Context rules:
- Do not use lastRecommendation just because it exists.
- Use basePlan = "last_recommendation" only if the user clearly references the previous recommendation.
- Use basePlan = "current_plan" only if the user asks to add/change something in their current plan/schedule/course list.
- For broad add/change requests, ask one concise follow-up question instead of guessing several courses.
- If adding may exceed the user's credit range, ask whether to replace an existing course or allow overflow.

searchMode values:
- instructor: the user wants courses taught by a person.
- subject: the user wants a specific course/topic/subject.
- time: the user asks about class time.
- course_type: the user asks for core/GE/elective/requirement style.
- credit_mix: the user asks for a credit target or balance.
- general_plan: the user gives a broad goal/style/direction.
- unknown: unclear.

query rules:
- query is a clean natural search/planning phrase for the planner.
- Keep query faithful to the user's meaning.
- Do not insert phrases like "previous plan", "follow-up edit", or internal reasoning into query.

Output schema:
{
  "intent": "new_plan",
  "basePlan": "none",
  "usePreviousRecommendation": false,
  "searchMode": "general_plan",
  "query": "clean phrase from the student's request",
  "actions": [],
  "memoryUpdate": {
    "avoidKeywords": [],
    "preferredKeywords": []
  },
  "needsClarification": false,
  "clarifyingQuestion": null
}
''',
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'hasLastRecommendation': lastRecommendationIds.isNotEmpty,
        'lastRecommendationIds': lastRecommendationIds.take(20).toList(),
        'plannedCourseIds': plannedCourseIds.take(20).toList(),
        'userPreferences': userPreferences,
      })),
      temperature: 0.02,
      maxTokens: 550,
    );

    if (content == null || content.trim().isEmpty) {
      return promptFirstFallback;
    }

    try {
      final jsonText = _extractJsonObject(content);
      final parsed = jsonDecode(jsonText);

      if (parsed is! Map) {
        return promptFirstFallback;
      }

      final resolved = BaoBaoCourseIntent.fromJson(
        Map<String, dynamic>.from(parsed),
      );

      if (_looksLikeBaoBaoInternalPlanningPrompt(userMessage) &&
          (resolved.isMemoryUpdate || resolved.isClearMemory)) {
        return promptFirstFallback;
      }

      // Trust the model's structured intent. Do not override it with local
      // keyword/professor/course-name parsing. That was the source of many
      // "same output / wrong exact search" bugs.
      return resolved;
    } catch (error) {
      print('Bao-Bao intent parse failed: $error');
      return promptFirstFallback;
    }
  }


  BaoBaoCourseIntent _normalizeResolvedIntentWithContext({
    required BaoBaoCourseIntent resolved,
    required String userMessage,
    required List<String> plannedCourseIds,
  }) {
    final lower = userMessage.toLowerCase().trim();

    if (_looksLikeOpenEndedStudyGoal(userMessage) &&
        !resolved.isMemoryUpdate &&
        !resolved.isClearMemory &&
        !resolved.isClarificationNeeded) {
      return BaoBaoCourseIntent(
        intent: 'new_plan',
        basePlan: 'none',
        actions: const [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
        usePreviousRecommendation: false,
        searchMode: 'general_plan',
        query: _cleanOpenEndedGoalQuery(userMessage),
      );
    }

    final professorTokensFromMessage = _extractProfessorNameTokens(userMessage);
    if (professorTokensFromMessage.isNotEmpty) {
      final explicitlyCurrent = _explicitlyReferencesCurrentPlan(lower);
      final query = professorTokensFromMessage.join(' ');

      return BaoBaoCourseIntent(
        intent: explicitlyCurrent && plannedCourseIds.isNotEmpty
            ? 'modify_previous_plan'
            : 'direct_search',
        basePlan: explicitlyCurrent && plannedCourseIds.isNotEmpty
            ? 'current_plan'
            : 'none',
        actions: explicitlyCurrent && plannedCourseIds.isNotEmpty
            ? [
                {
                  'type': 'add',
                  'subject': query,
                  'count': 1,
                }
              ]
            : const [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
        usePreviousRecommendation: false,
        searchMode: 'instructor',
        query: query,
      );
    }

    return resolved;
  }

  bool _looksLikeOpenEndedStudyGoal(String message) {
    final lower = message.toLowerCase().trim();
    if (lower.isEmpty) return false;

    if (_looksLikeBaoBaoInternalPlanningPrompt(message)) return false;
    if (_hasExplicitProfessorSearchIntent(message)) return false;

    final hasGoalVerb = RegExp(
      r'\b(i\s+want\s+to\s+(study|focus|learn|prepare|build)|help\s+me\s+(plan|study|prepare)|plan\s+(for|around)|build\s+(a\s+)?plan\s+(for|around)|interested\s+in|focus\s+on|career\s+in|become)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    final hasMixSignal = RegExp(
      r'\b(with\s+(a\s+bit\s+of|some)|mix\s+of|combine|combination\s+of|and\s+a\s+bit\s+of)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    final asksSingleLookup = RegExp(
      r'\b(find|search|show|give|add|include|remove|drop|replace|taught\s+by|prof|professor|teacher|instructor)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (hasGoalVerb) return true;
    return hasMixSignal && !asksSingleLookup;
  }

  String _cleanOpenEndedGoalQuery(String message) {
    var text = message.toLowerCase();

    text = text
        .replaceAll(RegExp(r'\b(bao|baobao|bao-bao|please|pls|can\s+you|could\s+you|help\s+me|i\s+want\s+to|i\s+wanna|i\s+would\s+like\s+to|study|focus\s+on|learn|prepare\s+for|build\s+a\s+plan\s+for|plan\s+for|plan\s+around|courses?|classes?|a\s+bit\s+of|some)\b'), ' ')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text.isEmpty ? message.trim() : text;
  }

  BaoBaoCourseIntent _localBaoBaoIntentFallback({
    required String userMessage,
    required List<String> lastRecommendationIds,
    required List<String> plannedCourseIds,
  }) {
    final lower = userMessage.toLowerCase().trim();
    final hasLast = lastRecommendationIds.isNotEmpty;
    final hasCurrentPlan = plannedCourseIds.isNotEmpty;

    if (_looksLikeBaoBaoInternalPlanningPrompt(userMessage)) {
      return const BaoBaoCourseIntent(
        intent: 'new_plan',
        basePlan: 'none',
        actions: [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
      );
    }

    if (lower.contains('clear bao-bao memory') ||
        lower.contains('clear baobao memory') ||
        lower.contains('reset bao-bao memory') ||
        lower.contains('reset baobao memory') ||
        lower.contains('forget bao-bao memory') ||
        lower.contains('forget baobao memory')) {
      return const BaoBaoCourseIntent(
        intent: 'clear_memory',
        basePlan: 'none',
        actions: [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
      );
    }

    final professorTokens = _extractProfessorNameTokens(userMessage);
    if (professorTokens.isNotEmpty) {
      final query = professorTokens.join(' ');
      final explicitlyCurrent = _explicitlyReferencesCurrentPlan(lower);

      return BaoBaoCourseIntent(
        intent: explicitlyCurrent && hasCurrentPlan
            ? 'modify_previous_plan'
            : 'direct_search',
        basePlan: explicitlyCurrent && hasCurrentPlan ? 'current_plan' : 'none',
        actions: explicitlyCurrent && hasCurrentPlan
            ? [
                {
                  'type': 'add',
                  'subject': query,
                  'count': 1,
                }
              ]
            : const [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
        usePreviousRecommendation: false,
        searchMode: 'instructor',
        query: query,
      );
    }

    final persistentMemory = lower.contains('remember') ||
        lower.contains('from now on') ||
        lower.contains('next time') ||
        lower.contains('again') ||
        lower.contains('anymore') ||
        lower.contains('future') ||
        lower.contains('never recommend');

    if (persistentMemory) {
      final avoid = _extractIntentKeyword(
        userMessage,
        patterns: const [
          r"(?:do not|don't|dont|never)\s+recommend\s+(.+)",
          r"(?:avoid|skip)\s+(.+)",
          r"i\s+(?:do not|don't|dont)\s+like\s+(.+)",
          r"i\s+(?:hate|dislike)\s+(.+)",
        ],
      );

      if (avoid != null) {
        return BaoBaoCourseIntent(
          intent: 'memory_update',
          basePlan: 'none',
          actions: const [],
          memoryUpdate: {
            'avoidKeywords': [avoid],
            'preferredKeywords': const <String>[],
          },
          needsClarification: false,
          clarifyingQuestion: null,
        );
      }

      final prefer = _extractIntentKeyword(
        userMessage,
        patterns: const [
          r"remember\s+(?:that\s+)?i\s+(?:prefer|like|want)\s+(.+)",
          r"i\s+(?:prefer|like|want)\s+(.+)",
          r"prefer\s+(.+)",
        ],
      );

      if (prefer != null) {
        return BaoBaoCourseIntent(
          intent: 'memory_update',
          basePlan: 'none',
          actions: const [],
          memoryUpdate: {
            'avoidKeywords': const <String>[],
            'preferredKeywords': [prefer],
          },
          needsClarification: false,
          clarifyingQuestion: null,
        );
      }
    }

    final hasFollowUpWords = lower.contains('before') ||
        lower.contains('previous') ||
        lower.contains('same') ||
        lower.contains('that') ||
        lower.contains('it') ||
        lower.contains('recommend before') ||
        lower.contains('recommended before') ||
        lower.contains('what u recommend') ||
        lower.contains('what you recommend') ||
        lower.contains('i like it') ||
        lower.contains('liked it');

    final addMatch = RegExp(
      r'\b(?:add|include|plus|with|need|want)\s+(?:one|1|a|an|some|more)?\s*([a-zA-Z0-9\u4e00-\u9fff &+.-]+)',
      caseSensitive: false,
    ).firstMatch(userMessage);

    final removeMatch = RegExp(
      r'\b(?:remove|drop|delete|without|no)\s+([a-zA-Z0-9\u4e00-\u9fff &+.-]+)',
      caseSensitive: false,
    ).firstMatch(userMessage);

    final actions = <Map<String, dynamic>>[];

    if (removeMatch != null) {
      final subject = _cleanIntentSubject(removeMatch.group(1) ?? '');
      if (subject.isNotEmpty) {
        actions.add({
          'type': 'remove',
          'subject': _canonicalIntentSubject(subject),
          'count': null,
        });
      }
    }

    if (addMatch != null) {
      final subject = _cleanIntentSubject(addMatch.group(1) ?? '');
      if (subject.isNotEmpty) {
        actions.add({
          'type': 'add',
          'subject': _canonicalIntentSubject(subject),
          'count': _extractSmallCount(lower) ?? 1,
        });
      }
    } else if (_looksLikeAddOnlyFollowUp(userMessage)) {
      final subject = _extractBareSubject(lower);
      if (subject != null) {
        actions.add({
          'type': 'add',
          'subject': _canonicalIntentSubject(subject),
          'count': _extractSmallCount(lower) ?? 1,
        });
      }
    }

    if (actions.isNotEmpty) {
      final provisionalIntent = BaoBaoCourseIntent(
        intent: hasLast || hasCurrentPlan || hasFollowUpWords
            ? 'modify_previous_plan'
            : 'direct_search',
        basePlan: hasLast ? 'last_recommendation' : 'current_plan',
        actions: actions,
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
        usePreviousRecommendation: hasLast,
        searchMode: _guessSearchModeFromText(lower),
        query: actions
            .map((action) => (action['subject'] ?? action['withSubject'] ?? '').toString())
            .where((item) => item.trim().isNotEmpty)
            .join(' '),
      );

      final clarificationIntent = _clarificationForAmbiguousBroadIntent(
        provisionalIntent,
        userPreferences: null,
        userMessage: userMessage,
      );

      if (clarificationIntent != null) {
        return clarificationIntent;
      }

      final explicitlyPrevious = _explicitlyReferencesPreviousPlan(lower);
      final explicitlyCurrent = _explicitlyReferencesCurrentPlan(lower);

      if (explicitlyPrevious && (hasLast || hasCurrentPlan)) {
        return BaoBaoCourseIntent(
          intent: 'modify_previous_plan',
          basePlan: hasLast ? 'last_recommendation' : 'current_plan',
          actions: actions,
          memoryUpdate: null,
          needsClarification: false,
          clarifyingQuestion: null,
          usePreviousRecommendation: hasLast,
          searchMode: _guessSearchModeFromText(lower),
          query: actions
              .map((action) => (action['subject'] ?? action['withSubject'] ?? '').toString())
              .where((item) => item.trim().isNotEmpty)
              .join(' '),
        );
      }

      if (explicitlyCurrent && hasCurrentPlan) {
        return BaoBaoCourseIntent(
          intent: 'modify_previous_plan',
          basePlan: 'current_plan',
          actions: actions,
          memoryUpdate: null,
          needsClarification: false,
          clarifyingQuestion: null,
          usePreviousRecommendation: false,
          searchMode: _guessSearchModeFromText(lower),
          query: actions
              .map((action) => (action['subject'] ?? action['withSubject'] ?? '').toString())
              .where((item) => item.trim().isNotEmpty)
              .join(' '),
        );
      }

      return BaoBaoCourseIntent(
        intent: 'direct_search',
        basePlan: 'none',
        actions: actions,
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
        usePreviousRecommendation: false,
        searchMode: _guessSearchModeFromText(lower),
        query: actions
            .map((action) => (action['subject'] ?? action['withSubject'] ?? '').toString())
            .where((item) => item.trim().isNotEmpty)
            .join(' '),
      );
    }

    final veryShort = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 2;
    if (veryShort && (lower == 'do what' || lower == 'what' || lower == 'hmm')) {
      return const BaoBaoCourseIntent(
        intent: 'clarification_needed',
        basePlan: 'none',
        actions: [],
        memoryUpdate: null,
        needsClarification: true,
        clarifyingQuestion: 'Do you want Bao-Bao to continue the previous recommendation, add something to your current plan, or create a new plan?',
      );
    }

    if (lower == 'hi' || lower == 'hello' || lower == 'hey') {
      return const BaoBaoCourseIntent(
        intent: 'small_talk',
        basePlan: 'none',
        actions: [],
        memoryUpdate: null,
        needsClarification: false,
        clarifyingQuestion: null,
      );
    }

    return const BaoBaoCourseIntent(
      intent: 'new_plan',
      basePlan: 'none',
      actions: [],
      memoryUpdate: null,
      needsClarification: false,
      clarifyingQuestion: null,
    );
  }

  BaoBaoCourseIntent? _clarificationForAmbiguousBroadIntent(
    BaoBaoCourseIntent intent, {
    required Map<String, dynamic>? userPreferences,
    required String userMessage,
  }) {
    if (intent.isClarificationNeeded ||
        intent.isMemoryUpdate ||
        intent.isClearMemory) {
      return null;
    }

    final ambiguousBroadAdd =
        _intentAsksToAddBroadCourseCategory(intent) ||
        _messageLooksLikeBroadAddOrEdit(userMessage, intent);

    if (!ambiguousBroadAdd) {
      return null;
    }

    final creditLabel = _creditRangeLabelFromPreferences(userPreferences);
    final creditSentence = creditLabel == null
        ? ''
        : ' Your target is $creditLabel credits, so should Bao-Bao replace an existing course or allow the plan to exceed that range?';

    return BaoBaoCourseIntent(
      intent: 'clarification_needed',
      basePlan: 'none',
      actions: const [],
      memoryUpdate: null,
      needsClarification: true,
      clarifyingQuestion:
          'Which exact course should Bao-Bao add, and how many? Tell me a subject, professor, language, or course name.$creditSentence',
      usePreviousRecommendation: false,
      searchMode: 'unknown',
      query: '',
    );
  }

  bool _messageLooksLikeBroadAddOrEdit(
    String userMessage,
    BaoBaoCourseIntent intent,
  ) {
    final lower = userMessage.toLowerCase();

    final asksToChangePlan = RegExp(
      r'\b(add|include|plus|with|another|more|replace|swap|change|insert)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (!asksToChangePlan) {
      return false;
    }

    final candidateText = [
      userMessage,
      intent.query,
      for (final action in intent.actions)
        (action['subject'] ?? action['withSubject'] ?? '').toString(),
    ].join(' ');

    return _isBroadCourseCategoryWithoutDetail(candidateText);
  }

  bool _intentAsksToAddBroadCourseCategory(BaoBaoCourseIntent intent) {
    final addLikeActions = intent.actions.where((action) {
      final type = action['type']?.toString().toLowerCase().trim() ?? '';
      return type == 'add' || type == 'include' || type == 'replace';
    }).toList();

    if (addLikeActions.isEmpty) {
      return false;
    }

    for (final action in addLikeActions) {
      final subject = (action['subject'] ?? action['withSubject'] ?? intent.query)
          .toString()
          .trim();

      if (_isBroadCourseCategoryWithoutDetail(subject)) {
        return true;
      }
    }

    return false;
  }

  bool _isBroadCourseCategoryWithoutDetail(String raw) {
    var text = raw.toLowerCase();

    text = text
        .replaceAll(RegExp(r'[.!?。！？,，]+'), ' ')
        .replaceAll(
          RegExp(
            r'\b(add|include|plus|with|give|show|find|search|need|want|please|pls|one|1|a|an|some|more|another|other|extra|additional|new|to|the|my|me|i|we|you|u|can|could|would|bao|baobao|bao-bao|plan|course|courses|class|classes)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) {
      return true;
    }

    final tokens = text
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();

    // These are not special cases like "language" only. They are broad academic
    // category words. If the remaining request contains only these category
    // words, Bao-Bao should ask a follow-up instead of guessing many courses.
    final genericTokens = {
      'language',
      'foreign',
      'ge',
      'general',
      'education',
      'elective',
      'electives',
      'free',
      'required',
      'requirement',
      'requirements',
      'core',
      'basic',
      'major',
      'department',
      'professional',
      'lab',
      'laboratory',
      'curriculum',
      'bucket',
      'any',
    };

    return tokens.isNotEmpty && tokens.every(genericTokens.contains);
  }

  String? _creditRangeLabelFromPreferences(Map<String, dynamic>? userPreferences) {
    final range = _targetCreditRangeFromPreferences(userPreferences);

    if (range.min == null && range.max == null) {
      return null;
    }

    if (range.min != null && range.max != null && range.min != range.max) {
      return '${range.min}–${range.max}';
    }

    return '${range.min ?? range.max}';
  }

  bool _looksLikeBaoBaoInternalPlanningPrompt(String message) {
    final lower = message.toLowerCase();

    return lower.contains('automatically create') ||
        lower.contains('first check what data') ||
        lower.contains('if curriculum is available') ||
        lower.contains('if curriculum is missing') ||
        lower.contains('avoid completed courses') ||
        lower.contains('duplicated course sections') ||
        lower.contains('schedule conflicts') ||
        lower.contains('too advanced for the student year');
  }

  bool _looksLikeAddOnlyFollowUp(String message) {
    final lower = message.toLowerCase().trim();

    return lower.startsWith('add ') ||
        lower.startsWith('include ') ||
        lower.startsWith('plus ') ||
        lower.contains(' add ') ||
        lower.contains(' include ') ||
        lower.contains('same but') ||
        lower.contains('i like it but') ||
        lower.contains('what u recommend before') ||
        lower.contains('what you recommend before');
  }


  bool _explicitlyReferencesPreviousPlan(String lower) {
    return lower.contains('before') ||
        lower.contains('previous') ||
        lower.contains('same') ||
        lower.contains('that plan') ||
        lower.contains('that one') ||
        lower.contains('what u recommend') ||
        lower.contains('what you recommend') ||
        lower.contains('recommended before') ||
        lower.contains('i like it') ||
        lower.contains('liked it') ||
        lower.contains('keep that');
  }

  bool _explicitlyReferencesCurrentPlan(String lower) {
    return lower.contains('my course') ||
        lower.contains('my courses') ||
        lower.contains('my plan') ||
        lower.contains('current plan') ||
        lower.contains('my schedule') ||
        lower.contains('to the plan') ||
        lower.contains('to my course') ||
        lower.contains('to my plan') ||
        lower.contains('to my schedule');
  }

  String _guessSearchModeFromText(String lower) {
    if (lower.contains('professor') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by') ||
        RegExp(r'\b(by|from|with)\s+[^\s]+').hasMatch(lower)) {
      return 'instructor';
    }

    if (lower.contains('morning') ||
        lower.contains('afternoon') ||
        lower.contains('evening') ||
        lower.contains('night')) {
      return 'time';
    }

    if (lower.contains('core') || lower.contains('ge') || lower.contains('elective')) {
      return 'course_type';
    }

    if (lower.contains('credit')) {
      return 'credit_mix';
    }

    return 'subject';
  }

  int? _extractSmallCount(String lower) {
    final numeric = RegExp(r'\b([1-9])\b').firstMatch(lower);
    if (numeric != null) {
      return int.tryParse(numeric.group(1) ?? '');
    }

    if (lower.contains('one ')) return 1;
    if (lower.contains('two ')) return 2;
    if (lower.contains('three ')) return 3;
    if (lower.contains('four ')) return 4;
    if (lower.contains('five ')) return 5;

    return null;
  }

  String? _extractBareSubject(String lower) {
    final normalized = lower
        .replaceAll(RegExp(r'\b(add|include|plus|one|1|a|an|class|course|courses|please|pls)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return null;
    if (normalized.contains('calc')) return 'calculus';
    if (normalized.contains('calculus')) return 'calculus';
    if (normalized.contains('i2p')) return 'i2p';
    if (normalized.contains('database')) return 'database';
    if (normalized.contains('linear algebra')) return 'linear algebra';

    return normalized.length <= 50 ? normalized : null;
  }

  String? _extractIntentKeyword(
    String message, {
    required List<String> patterns,
  }) {
    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(message);
      if (match == null) continue;

      final cleaned = _cleanIntentSubject(match.group(1) ?? '');
      if (cleaned.isNotEmpty) return cleaned;
    }

    return null;
  }

  String _cleanIntentSubject(String raw) {
    var text = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?。！？]+$'), '')
        .replaceAll(RegExp(r'\b(before|previous|same|recommend|recommended|what|you|u|bao|baobao|bao-bao|it|but|also|please|pls|another|her|his|their|my|to|easy)\b'), ' ')
        .replaceAll(RegExp(r'\b(course|courses|class|classes|lesson|one|1|a|an|some|more|another|other|extra|additional|new)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length > 80) {
      text = text.substring(0, 80).trim();
    }

    return text;
  }

  String _canonicalIntentSubject(String subject) {
    final lower = subject.toLowerCase().trim();

    if (lower == 'calc' || lower.contains('calc ')) return 'calculus';
    if (lower.contains('calculus') || lower.contains('微積分')) return 'calculus';
    if (lower == 'db' || lower.contains('database')) return 'database';
    if (lower == 'os' || lower.contains('operating system')) return 'operating systems';
    if (lower == 'ds' || lower == 'dsa' || lower.contains('data structure')) return 'data structures';
    if (lower.contains('linear algebra')) return 'linear algebra';
    if (lower.contains('i2p')) return 'i2p';

    return lower;
  }

  // ============================================================
  // SMART AI COURSE RECOMMENDATION
  // ============================================================

  Future<List<String>> askBaoBaoRecommendedCourseIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
    Map<String, dynamic>? curriculum,
    Map<String, dynamic>? userPreferences,
    BaoBaoCourseIntent? intent,
  }) async {
    final enrichedUserPreferences =
        await _withAiGeneratedPreferenceSearchProfile(userPreferences);

    final rawPlan = await _makeAiSearchPlan(
      userMessage,
      intent: intent,
      userPreferences: enrichedUserPreferences,
    );

    // AI should be the planner brain. This step only adds preference context;
    // it does not convert the prompt into hardcoded course mappings.
    final plan = _enhancePlanWithUserPreferences(
      rawPlan,
      enrichedUserPreferences,
    );

    print('Bao-Bao final AI tool plan: ${plan.toDebugMap()}');

    final selectedIds = <String>[];
    final usedIds = <String>{};
    final usedCourseTitles = <String>{};
    final selectedCourses = <Map<String, dynamic>>[];

    final creditRange = _targetCreditRangeForPlan(
      plan,
      enrichedUserPreferences,
      intent,
    );
    final targetCreditMin = creditRange.min;
    final targetCreditMax = creditRange.max;
    int selectedCredits = 0;

    bool reachedTargetCredits() {
      if (targetCreditMin == null) return false;
      return selectedCredits >= targetCreditMin;
    }

    bool canAddCourse(Map<String, dynamic> course) {
      if (targetCreditMax == null) return true;

      final credits = _toInt(course['credits']);
      if (credits <= 0) return false;
      if (selectedCredits >= targetCreditMax) return false;

      return selectedCredits + credits <= targetCreditMax;
    }

    bool tryAddCourse(Map<String, dynamic> course) {
      final id = course['id']?.toString() ?? '';
      if (id.isEmpty || usedIds.contains(id)) return false;

      final titleKey = _normalizeSearchText(course['title']?.toString() ?? '');
      if (titleKey.isNotEmpty && usedCourseTitles.contains(titleKey)) {
        return false;
      }

      // Tool guardrail: the AI can reason, but the app must never allow
      // conflicting cards inside the same recommendation result.
      if (_hasScheduleConflictWithSelected(course, selectedCourses)) {
        return false;
      }

      if (!canAddCourse(course)) return false;

      selectedIds.add(id);
      usedIds.add(id);
      if (titleKey.isNotEmpty) usedCourseTitles.add(titleKey);
      selectedCredits += _toInt(course['credits']);
      selectedCourses.add(course);
      return true;
    }

    Future<int> askAiAndAddFromCandidates({
      required _SearchGroup group,
      required List<Map<String, dynamic>> candidates,
      required int alreadyAddedForGroup,
    }) async {
      var addedForGroup = alreadyAddedForGroup;

      final safeCandidates = candidates.where((course) {
        return !_hasScheduleConflictWithSelected(course, selectedCourses);
      }).toList();

      if (safeCandidates.isEmpty) {
        return addedForGroup;
      }

      final aiChosen = await _aiChooseCourseIds(
        userMessage: userMessage,
        group: group,
        candidates: safeCandidates,
        curriculum: curriculum,
        userPreferences: enrichedUserPreferences,
      );

      for (final id in aiChosen) {
        if (reachedTargetCredits()) break;
        if (addedForGroup >= group.count) break;
        if (usedIds.contains(id)) continue;

        final course = safeCandidates.firstWhere(
          (course) => course['id']?.toString() == id,
          orElse: () => {},
        );

        if (course.isEmpty) continue;
        if (tryAddCourse(course)) {
          addedForGroup++;
        }
      }

      return addedForGroup;
    }

    for (final group in plan.groups) {
      if (reachedTargetCredits()) break;

      int addedForThisGroup = 0;
      var attempts = 0;

      while (addedForThisGroup < group.count && attempts < 3) {
        attempts++;

        final candidates = _buildCandidatePool(
          group: group,
          catalog: courseCatalog,
          usedIds: usedIds,
          allowSpecialCourses: plan.allowSpecialCourses,
        ).where((course) {
          return !_hasScheduleConflictWithSelected(course, selectedCourses);
        }).toList();

        print(
          'Bao-Bao AI tool candidate count for "${group.query}" '
          '[subject=${group.subjectQuery}, mustSubject=${group.mustMatchSubject}, '
          'type=${group.requiredType}, time=${group.timePreference}, '
          'language=${group.language}, count=${group.count}, '
          'attempt=$attempts]: ${candidates.length}',
        );

        if (candidates.isEmpty) break;

        final before = addedForThisGroup;
        addedForThisGroup = await askAiAndAddFromCandidates(
          group: group,
          candidates: candidates,
          alreadyAddedForGroup: addedForThisGroup,
        );

        if (addedForThisGroup == before) {
          break;
        }
      }
    }

    // Only full-semester/general plans use the saved target-credit range.
    // Exact requests like "2 GE" should stay exactly 2 courses and should not
    // be padded with random fillers.
    if (targetCreditMin != null && selectedCredits < targetCreditMin) {
      final fillerGroup = _creditFillerSearchGroup(
        enrichedUserPreferences,
        language: _languagePreferenceFromPrefs(
          _preferenceMap(enrichedUserPreferences),
        ),
      );

      var attempts = 0;
      while (selectedCredits < targetCreditMin && attempts < 3) {
        attempts++;
        final candidates = _buildCandidatePool(
          group: fillerGroup,
          catalog: courseCatalog,
          usedIds: usedIds,
          allowSpecialCourses: plan.allowSpecialCourses,
        ).where((course) {
          return !_hasScheduleConflictWithSelected(course, selectedCourses);
        }).toList();

        if (candidates.isEmpty) break;

        final beforeCount = selectedIds.length;
        await askAiAndAddFromCandidates(
          group: fillerGroup,
          candidates: candidates,
          alreadyAddedForGroup: 0,
        );

        if (selectedIds.length == beforeCount) break;
      }
    }

    print(
      'Bao-Bao selected ${selectedIds.length} courses, '
      '$selectedCredits/${creditRange.toString()} target.',
    );

    return selectedIds;
  }

  bool _hasScheduleConflictWithSelected(
    Map<String, dynamic> course,
    List<Map<String, dynamic>> selectedCourses,
  ) {
    final courseSlots = _courseScheduleSlotKeys(course);
    if (courseSlots.isEmpty) return false;

    for (final selected in selectedCourses) {
      final selectedSlots = _courseScheduleSlotKeys(selected);
      if (selectedSlots.isEmpty) continue;
      if (courseSlots.intersection(selectedSlots).isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  Set<String> _courseScheduleSlotKeys(Map<String, dynamic> course) {
    final keys = <String>{};

    final slotText = [
      course['slotCode'],
      course['timeSlot'],
      course['schedule'],
      course['classTime'],
      course['courseTime'],
      course['period'],
      course['periods'],
    ].whereType<Object>().map((item) => item.toString()).join(' ');

    keys.addAll(_parseNthuSlotText(slotText));

    final day = _toInt(course['day']);
    final startSlot = _toInt(course['startSlot']);
    final duration = _toInt(course['duration']);

    if (day >= 1 && day <= 7 && duration > 0) {
      for (int offset = 0; offset < duration; offset++) {
        keys.add('D$day:${startSlot + offset}');
      }
    }

    return keys;
  }

  Set<String> _parseNthuSlotText(String raw) {
    final text = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final keys = <String>{};
    const dayLetters = {'M', 'T', 'W', 'R', 'F', 'S', 'U'};
    const periodLetters = {'1', '2', '3', '4', 'N', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D'};

    String? currentDay;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      final previous = i == 0 ? '' : text[i - 1];
      final next = i + 1 < text.length ? text[i + 1] : '';

      if (dayLetters.contains(ch) && periodLetters.contains(next)) {
        // Avoid reading location words such as DELTA as time slots.
        if (previous.isNotEmpty && RegExp(r'[A-Z]').hasMatch(previous)) {
          continue;
        }

        currentDay = ch;
        continue;
      }

      if (currentDay != null && periodLetters.contains(ch)) {
        keys.add('$currentDay:$ch');
      }
    }

    return keys;
  }

  _BaoBaoCreditRange _targetCreditRangeForPlan(
    _AiSearchPlan plan,
    Map<String, dynamic>? rawPreferences,
    BaoBaoCourseIntent? intent,
  ) {
    // Exact search/edit/type-count requests should not be padded to the saved
    // semester credit target. Example: "recommend 2 GE" means exactly 2 GE,
    // not 2 GE + random fillers until 16–18 credits.
    if (intent != null) {
      final mode = intent.searchMode.toLowerCase().trim();
      if (intent.isDirectSearch ||
          intent.isModifyPreviousPlan ||
          mode == 'course_type' ||
          mode == 'subject' ||
          mode == 'instructor' ||
          mode == 'time') {
        return const _BaoBaoCreditRange(min: null, max: null);
      }
    }

    if (plan.targetCredits != null && plan.targetCredits! > 0) {
      return _BaoBaoCreditRange(
        min: plan.targetCredits,
        max: plan.targetCredits,
      );
    }

    final looksLikeExactTypeRequest = plan.groups.isNotEmpty &&
        plan.groups.every((group) => group.requiredType != 'any') &&
        plan.groups.fold<int>(0, (sum, group) => sum + group.count) <= 8;

    if (looksLikeExactTypeRequest) {
      return const _BaoBaoCreditRange(min: null, max: null);
    }

    return _targetCreditRangeFromPreferences(rawPreferences);
  }

  _BaoBaoCreditRange _targetCreditRangeFromPreferences(
    Map<String, dynamic>? rawPreferences,
  ) {
    if (rawPreferences == null) {
      return const _BaoBaoCreditRange(min: null, max: null);
    }

    final prefs = rawPreferences['preferences'] is Map
        ? Map<String, dynamic>.from(rawPreferences['preferences'])
        : rawPreferences;

    final value = prefs['targetCreditLoad']?.toString() ?? '';

    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();

    if (numbers.isEmpty) {
      return const _BaoBaoCreditRange(min: null, max: null);
    }

    if (numbers.length == 1) {
      return _BaoBaoCreditRange(min: numbers.first, max: numbers.first);
    }

    final first = numbers.first;
    final second = numbers[1];

    return _BaoBaoCreditRange(
      min: math.min(first, second),
      max: math.max(first, second),
    );
  }

  _SearchGroup _creditFillerSearchGroup(
    Map<String, dynamic>? rawPreferences, {
    required String language,
  }) {
    final prefs = _preferenceMap(rawPreferences);
    final profileText = [
      _departmentPreferenceQuery(prefs),
      _careerPreferenceQuery(prefs),
      _gePreferenceQuery(prefs),
      _memoryPreferenceQuery(prefs),
      'real course useful semester plan',
    ].where((item) => item.trim().isNotEmpty).join(' ');

    return _SearchGroup(
      query: profileText,
      subjectQuery: null,
      subjectPhrases: const [],
      mustMatchSubject: false,
      count: 30,
      credits: null,
      requiredType: 'any',
      timePreference: 'any',
      language: language,
      // minLimit 0 is used as a harmless broad-search constraint so
      // Bao-Bao can still rank real courses even when the query words do
      // not literally appear in course titles.
      minLimit: 0,
      maxLimit: null,
      mustHave: const [],
      avoid: const [
        'thesis',
        'seminar',
        'research',
        'lab rotation',
        'dissertation',
        '專題',
        '論文',
        '研究',
        '書報',
      ],
    );
  }

  int? _targetCreditsFromPreferences(Map<String, dynamic>? rawPreferences) {
    if (rawPreferences == null) return null;

    final prefs = rawPreferences['preferences'] is Map
        ? Map<String, dynamic>.from(rawPreferences['preferences'])
        : rawPreferences;

    final value = prefs['targetCreditLoad']?.toString() ?? '';

    final numbers = RegExp(r'\d+')
        .allMatches(value)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();

    if (numbers.isEmpty) return null;

    if (numbers.length >= 2) {
      return numbers[1];
    }

    return numbers.first;
  }

  List<Map<String, dynamic>> _localRankCoursesWithDiversity(
    _SearchGroup group,
    List<Map<String, dynamic>> candidates,
  ) {
    final ranked = _localRankCourses(group, candidates);

    if (ranked.length <= group.count) {
      return ranked;
    }

  
    final windowSize = math.min(
      ranked.length,
      math.max(group.count * 3, group.count + 4),
    );

    final topWindow = ranked.take(windowSize).toList();
    final rest = ranked.skip(windowSize).toList();

    final seed = DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 10);
    topWindow.shuffle(math.Random(seed + group.query.hashCode));

    return [
      ...topWindow,
      ...rest,
    ];
  }
  
  _AiSearchPlan _adjustPlanWithUserHints(
    _AiSearchPlan plan,
    String userMessage, {
    Map<String, dynamic>? curriculum,
    Map<String, dynamic>? userPreferences,
    BaoBaoCourseIntent? intent,
  }) {
    final lower = userMessage.toLowerCase();
    final hasCurriculum = _hasUsableCurriculum(curriculum);

    final cleanIntentPlan = _cleanPlanFromResolvedIntent(intent);
    if (cleanIntentPlan != null) {
      return cleanIntentPlan;
    }

    if (intent != null &&
        intent.intent == 'new_plan' &&
        intent.searchMode.toLowerCase().trim() == 'general_plan') {
      return _buildPromptFirstGeneralPlan(
        aiPlan: plan,
        userMessage: userMessage,
        intent: intent,
        userPreferences: userPreferences,
      );
    }


    if (intent != null && !_isAutoStarterRequest(userMessage)) {
      return _enhancePlanWithUserPreferences(
        plan,
        userPreferences,
      );
    }

    if (_isAvoidEarlyMorningPlanRequest(userMessage)) {
      return _buildNoEarlyMorningGeneralPlan(
        userMessage,
        userPreferences,
      );
    }

    // Auto starter and curriculum-planning prompts are handled before normal credit mix,
    // because they often contain words like curriculum, core, GE, and credits.
    if (_isAutoStarterRequest(userMessage)) {
      if (hasCurriculum) {
        final curriculumPlan = _buildDynamicCurriculumPlanningPlan(
          userMessage,
          curriculum!,
        );

        if (curriculumPlan.groups.isNotEmpty) {
          return _enhancePlanWithUserPreferences(
            curriculumPlan,
            userPreferences,
          );
        }
      }

      return _buildNoCurriculumPreferenceStarterPlan(
        userMessage,
        userPreferences,
      );
    }

    // Curriculum planning must be checked before credit mix,
    // because curriculum prompts may also contain "20 credits", "core", "GE", etc.
    if (_isCurriculumPlanningRequest(userMessage)) {
      if (hasCurriculum) {
        final curriculumPlan = _buildDynamicCurriculumPlanningPlan(
          userMessage,
          curriculum!,
        );

        if (curriculumPlan.groups.isNotEmpty) {
          return _enhancePlanWithUserPreferences(
            curriculumPlan,
            userPreferences,
          );
        }
      }

      return _buildNoCurriculumPreferenceStarterPlan(
        userMessage,
        userPreferences,
      );
    }

    if (_looksLikeOpenEndedStudyGoal(userMessage)) {
      return _buildOpenEndedGoalPlan(
        userMessage,
        userPreferences,
      );
    }

    if (_isLightEasyRequest(userMessage)) {
      return _buildLightEasyPlan(userMessage);
    }

    if (_isCreditMixRequest(userMessage)) {
      return _buildCreditMixPlan(userMessage);
    }

    final asksForOne =
        RegExp(r'\b(one|single|1)\b').hasMatch(lower) &&
        !lower.contains('all ') &&
        !RegExp(r'\b(two|three|four|five|six|seven|eight|nine|ten|[2-9])\b')
            .hasMatch(lower);

    final professorTokens = _hasExplicitProfessorSearchIntent(userMessage)
        ? _extractProfessorNameTokens(userMessage)
        : const <String>[];

    final hasProfessorSearch = professorTokens.isNotEmpty;

    final adjustedGroups = plan.groups.map((group) {
      if (hasProfessorSearch) {
        return group.copyWith(
          query: '${professorTokens.join(' ')} professor instructor teacher',
          subjectPhrases: const [],
          mustMatchSubject: false,
          clearSubject: true,
          mustHave: _mergeStringLists(group.mustHave, professorTokens),
          count: asksForOne && plan.groups.length == 1 ? 1 : group.count,
        );
      }

      return group.copyWith(
        count: asksForOne && plan.groups.length == 1 ? 1 : group.count,
      );
    }).toList();

    return _AiSearchPlan(
      targetCredits: plan.targetCredits,
      allowSpecialCourses: plan.allowSpecialCourses,
      groups: adjustedGroups,
    );
  }



  bool _isAvoidEarlyMorningPlanRequest(String message) {
    final lower = message.toLowerCase();

    return (lower.contains('recommend') ||
            lower.contains('suggest') ||
            lower.contains('plan') ||
            lower.contains('course') ||
            lower.contains('courses') ||
            lower.contains('class') ||
            lower.contains('classes')) &&
        (lower.contains('avoid early morning') ||
            lower.contains('no early morning') ||
            lower.contains('avoid morning') ||
            lower.contains('no morning') ||
            lower.contains('not morning'));
  }

  _AiSearchPlan _buildNoEarlyMorningGeneralPlan(
    String message,
    Map<String, dynamic>? userPreferences,
  ) {
    final prefs = _preferenceMap(userPreferences);
    final lower = message.toLowerCase();
    final targetCredits = _extractTargetCreditCount(lower);
    final query = [
      _departmentPreferenceQuery(prefs),
      _careerPreferenceQuery(prefs),
      _gePreferenceQuery(prefs),
      _memoryPreferenceQuery(prefs),
      'useful course plan avoid early morning no morning',
    ].where((item) => item.trim().isNotEmpty).join(' ');

    return _AiSearchPlan(
      targetCredits: targetCredits,
      allowSpecialCourses: false,
      groups: [
        _SearchGroup(
          query: query,
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: 12,
          credits: null,
          requiredType: 'any',
          timePreference: 'no_morning',
          language: _languagePreferenceFromPrefs(prefs),
          minLimit: null,
          maxLimit: null,
          mustHave: const [],
          avoid: const [
            'thesis',
            'seminar',
            'research',
            'lab rotation',
            'dissertation',
            '專題',
            '論文',
            '研究',
            '書報',
          ],
        ),
      ],
    );
  }

  _AiSearchPlan? _cleanPlanFromResolvedIntent(BaoBaoCourseIntent? intent) {
    if (intent == null) {
      return null;
    }

    final mode = intent.searchMode.toLowerCase().trim();
    final query = _cleanResolvedIntentQuery(intent);

    if (mode == 'general_plan' || _looksLikeOpenEndedStudyGoal(query)) {
      return null;
    }

    if (query.isEmpty) {
      return null;
    }

    if (mode == 'instructor') {
      final instructorQuery = _cleanInstructorQueryFromText(query);

      if (instructorQuery.isEmpty) {
        return null;
      }

      return _AiSearchPlan(
        targetCredits: null,
        allowSpecialCourses: false,
        groups: [
          _SearchGroup(
            query: '$instructorQuery professor instructor teacher',
            subjectQuery: null,
            subjectPhrases: const [],
            mustMatchSubject: false,
            count: 12,
            credits: null,
            requiredType: 'any',
            timePreference: 'any',
            language: 'any',
            minLimit: null,
            maxLimit: null,
            mustHave: [
              '__BAOBAO_INSTRUCTOR_MATCH__',
              instructorQuery,
            ],
            avoid: const [],
          ),
        ],
      );
    }

    if (mode == 'subject' ||
        (intent.isModifyPreviousPlan && intent.actions.isNotEmpty)) {
      return _AiSearchPlan(
        targetCredits: null,
        allowSpecialCourses: false,
        groups: [
          _SearchGroup(
            query: query,
            subjectQuery: query,
            subjectPhrases: [query],
            mustMatchSubject: true,
            count: _requestedSearchCountFromIntent(intent, fallback: intent.isModifyPreviousPlan ? 1 : 5),
            credits: null,
            requiredType: 'any',
            timePreference: 'any',
            language: 'any',
            minLimit: null,
            maxLimit: null,
            mustHave: const [],
            avoid: const [],
          ),
        ],
      );
    }

    if (mode == 'time') {
      return _AiSearchPlan(
        targetCredits: null,
        allowSpecialCourses: false,
        groups: [
          _SearchGroup(
            query: query,
            subjectQuery: null,
            subjectPhrases: const [],
            mustMatchSubject: false,
            count: 12,
            credits: null,
            requiredType: 'any',
            timePreference: _normalizeTimePreference(query),
            language: 'any',
            minLimit: null,
            maxLimit: null,
            mustHave: const [],
            avoid: const [],
          ),
        ],
      );
    }

    return null;
  }

  int _requestedSearchCountFromIntent(
    BaoBaoCourseIntent intent, {
    required int fallback,
  }) {
    final counts = <int>[];

    for (final action in intent.actions) {
      final value = action['count'];
      if (value is int && value > 0) {
        counts.add(value);
      } else if (value is num && value > 0) {
        counts.add(value.round());
      } else {
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null && parsed > 0) {
          counts.add(parsed);
        }
      }
    }

    if (counts.isEmpty) {
      return fallback;
    }

    return counts.fold<int>(0, (sum, count) => sum + count).clamp(1, 12);
  }

  String _cleanInstructorQueryFromText(String raw) {
    var text = _stripDiacritics(raw.toLowerCase());

    text = text
        .replaceAll(
          RegExp(
            r'\b(i|hear|heard|that|the|class|classes|course|courses|is|are|was|were|easy|good|nice|please|pls|add|include|give|show|find|search|her|his|their|my|to|into|plan|schedule|recommend|recommended|prof|professor|teacher|instructor|taught|by|from|with)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-zA-Z\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = _tokens(text)
        .where((token) => token.length >= 2)
        .take(4)
        .toList();

    return tokens.join(' ');
  }

  String _cleanResolvedIntentQuery(BaoBaoCourseIntent intent) {
    final directQuery = intent.query.trim();
    if (directQuery.isNotEmpty) {
      return directQuery;
    }

    final parts = <String>[];

    for (final action in intent.actions) {
      final type = action['type']?.toString() ?? '';
      if (type != 'add' && type != 'replace') continue;

      final subject = (action['subject'] ?? action['withSubject'] ?? '')
          .toString()
          .trim();
      if (subject.isNotEmpty) {
        parts.add(subject);
      }
    }

    return parts.join(' ').trim();
  }

  bool _isAutoStarterRequest(String message) {
    final lower = message.toLowerCase();

    return lower.contains('automatically create a useful first starter recommendation') ||
        lower.contains('automatically create a smart starter course plan') ||
        lower.contains('starter recommendation') ||
        lower.contains('starter course cards');
  }

  bool _hasUsableCurriculum(Map<String, dynamic>? curriculum) {
    if (curriculum == null || curriculum.isEmpty) {
      return false;
    }

    final groups = curriculum['requirementGroups'];
    return groups is List && groups.isNotEmpty;
  }


  _AiSearchPlan _buildPromptFirstGeneralPlan({
    required _AiSearchPlan aiPlan,
    required String userMessage,
    required BaoBaoCourseIntent intent,
    required Map<String, dynamic>? userPreferences,
  }) {
    final prefs = _preferenceMap(userPreferences);
    final intentQuery = intent.query.trim();
    final promptText = [
      intentQuery,
      userMessage,
    ].where((item) => item.trim().isNotEmpty).join(' ');

    final basePlan = aiPlan.groups.isNotEmpty
        ? aiPlan
        : _buildOpenEndedGoalPlan(promptText, userPreferences);

    final avoid = _mergeStringLists(
      const [
        'thesis',
        'seminar',
        'research',
        'lab rotation',
        'dissertation',
        '專題',
        '論文',
        '研究',
        '書報',
      ],
      _memoryAvoidKeywords(prefs),
    );

    final keepRequestedType = _promptExplicitlyRequestsCourseType(promptText);

    final groups = basePlan.groups.map((group) {
      final filteredMustHave = group.mustHave
          .where((item) => item.trim().toUpperCase() != '__BAOBAO_PREF_FIT__')
          .toList();

      return group.copyWith(
        query: [
          group.query,
          promptText,
        ].where((item) => item.trim().isNotEmpty).join(' '),
        clearSubject: true,
        subjectPhrases: const [],
        mustMatchSubject: false,
        // For natural goal prompts, do not force the old curriculum/department
        // type too early. Let the prompt and AI reranker decide relevance from
        // the real candidate list. Keep type only when the user explicitly asks
        // for CORE/GE/ELECTIVE.
        requiredType: keepRequestedType ? group.requiredType : 'any',
        language: 'any',
        mustHave: _mergeStringLists(
          filteredMustHave,
          const ['__BAOBAO_PROMPT_FIRST__'],
        ),
        avoid: _mergeStringLists(group.avoid, avoid),
      );
    }).toList();

    return _AiSearchPlan(
      targetCredits: aiPlan.targetCredits,
      allowSpecialCourses: aiPlan.allowSpecialCourses,
      groups: groups.isNotEmpty
          ? groups
          : _buildOpenEndedGoalPlan(promptText, userPreferences).groups,
    );
  }

  bool _promptExplicitlyRequestsCourseType(String message) {
    final lower = message.toLowerCase();

    return RegExp(
      r'\b(core|ge|general education|elective|requirement|required|lab|language)\b',
      caseSensitive: false,
    ).hasMatch(lower) ||
        lower.contains('通識') ||
        lower.contains('選修') ||
        lower.contains('必修') ||
        lower.contains('實驗');
  }

  _AiSearchPlan _buildOpenEndedGoalPlan(
    String message,
    Map<String, dynamic>? userPreferences,
  ) {
    final prefs = _preferenceMap(userPreferences);
    final cleanGoal = _cleanOpenEndedGoalQuery(message);
    final targetCredits = _extractTargetCreditCount(message.toLowerCase());
    final preferenceCreditRange = _targetCreditRangeFromPreferences(userPreferences);
    final planningTargetCredits = targetCredits ?? preferenceCreditRange.max;

    final memoryText = _memoryPreferenceQuery(prefs);
    final profileAvoid = _searchProfileText(
      prefs,
      const ['avoidKeywords'],
    );
    final avoid = _mergeStringLists(
      const [
        'thesis',
        'seminar',
        'research',
        'lab rotation',
        'dissertation',
        '專題',
        '論文',
        '研究',
        '書報',
      ],
      _mergeStringLists(
        _memoryAvoidKeywords(prefs),
        _splitSearchWords(profileAvoid),
      ),
    );

    final primaryCount = planningTargetCredits == null ? 4 : 5;
    final supportingCount = planningTargetCredits == null ? 3 : 4;
    final perspectiveCount = 2;

    final goalText = [
      cleanGoal,
      memoryText,
    ].where((item) => item.trim().isNotEmpty).join(' ');

    return _AiSearchPlan(
      targetCredits: targetCredits,
      allowSpecialCourses: false,
      groups: [
        _SearchGroup(
          query: [
            goalText,
            'foundation introductory applied academic direction',
          ].where((item) => item.trim().isNotEmpty).join(' '),
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: primaryCount,
          credits: null,
          requiredType: 'any',
          timePreference: 'any',
          language: 'any',
          minLimit: 0,
          maxLimit: null,
          mustHave: const ['__BAOBAO_PROMPT_FIRST__'],
          avoid: avoid,
        ),
        _SearchGroup(
          query: [
            goalText,
            'supporting interdisciplinary practical elective',
          ].where((item) => item.trim().isNotEmpty).join(' '),
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: supportingCount,
          credits: null,
          requiredType: 'any',
          timePreference: 'any',
          language: 'any',
          minLimit: 0,
          maxLimit: null,
          mustHave: const ['__BAOBAO_PROMPT_FIRST__'],
          avoid: avoid,
        ),
        _SearchGroup(
          query: [
            goalText,
            'context communication management society perspective',
          ].where((item) => item.trim().isNotEmpty).join(' '),
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: perspectiveCount,
          credits: null,
          requiredType: 'any',
          timePreference: 'any',
          language: 'any',
          minLimit: 0,
          maxLimit: null,
          mustHave: const ['__BAOBAO_PROMPT_FIRST__'],
          avoid: avoid,
        ),
      ],
    );
  }

  _AiSearchPlan _buildNoCurriculumPreferenceStarterPlan(
    String message,
    Map<String, dynamic>? userPreferences,
  ) {
    final prefs = _preferenceMap(userPreferences);
    final targetCredits = _extractTargetCreditCount(message.toLowerCase());
    final preferenceCreditRange = _targetCreditRangeFromPreferences(userPreferences);
    final planningTargetCredits = targetCredits ?? preferenceCreditRange.max;

    final careerText = _careerPreferenceQuery(prefs);
    final departmentText = _departmentPreferenceQuery(prefs);
    final geText = _gePreferenceQuery(prefs);
    final memoryText = _memoryPreferenceQuery(prefs);
    final profileAvoid = _searchProfileText(
      prefs,
      const ['avoidKeywords'],
    );
    final memoryAvoid = _mergeStringLists(
      _memoryAvoidKeywords(prefs),
      _splitSearchWords(profileAvoid),
    );

    final requestedCoreCount = _toInt(prefs['coreCourses']);
    final coreCount = requestedCoreCount > 0
        ? requestedCoreCount.clamp(1, 5)
        : (planningTargetCredits == null ? 2 : 2);

    final hasCareerSignal =
        _stringListFromAny(prefs['careerPaths']).isNotEmpty ||
        careerText.trim().isNotEmpty;

    final geCount = hasCareerSignal ? 1 : (planningTargetCredits == null ? 3 : 2);
    final electiveCount = hasCareerSignal ? 2 : (planningTargetCredits == null ? 4 : 3);

    final coreQuery = [
      departmentText,
      careerText,
      memoryText,
      'core foundation required major',
    ].where((item) => item.trim().isNotEmpty).join(' ');

    final electiveQuery = [
      departmentText,
      careerText,
      geText,
      memoryText,
      'elective useful practical supporting topic',
    ].where((item) => item.trim().isNotEmpty).join(' ');

    final geQuery = [
      geText,
      memoryText,
      'general education GE 通識',
    ].where((item) => item.trim().isNotEmpty).join(' ');

    return _AiSearchPlan(
      targetCredits: targetCredits,
      allowSpecialCourses: false,
      groups: [
        _SearchGroup(
          query: coreQuery,
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: coreCount,
          credits: null,
          requiredType: 'CORE',
          timePreference: 'any',
          language: _languagePreferenceFromPrefs(prefs),
          minLimit: null,
          maxLimit: null,
          mustHave: const ['__BAOBAO_PREF_FIT__'],
          avoid: _mergeStringLists(
            const [
              'thesis',
              'seminar',
              'research',
              'lab rotation',
              'dissertation',
              '專題',
              '論文',
              '研究',
              '書報',
            ],
            memoryAvoid,
          ),
        ),
        _SearchGroup(
          query: geQuery,
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: geCount,
          credits: null,
          requiredType: 'GE',
          timePreference: 'any',
          language: _languagePreferenceFromPrefs(prefs),
          minLimit: null,
          maxLimit: null,
          mustHave: geText.trim().isNotEmpty
              ? const ['__BAOBAO_PREF_FIT__']
              : const [],
          avoid: _mergeStringLists(
            const [
              'thesis',
              'seminar',
              'research',
              'lab rotation',
              'dissertation',
              '專題',
              '論文',
              '研究',
              '書報',
            ],
            memoryAvoid,
          ),
        ),
        _SearchGroup(
          query: electiveQuery,
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: electiveCount,
          credits: null,
          requiredType: 'ELECTIVE',
          timePreference: 'any',
          language: _languagePreferenceFromPrefs(prefs),
          minLimit: null,
          maxLimit: null,
          mustHave: const ['__BAOBAO_PREF_FIT__'],
          avoid: _mergeStringLists(
            const [
              'thesis',
              'seminar',
              'research',
              'lab rotation',
              'dissertation',
              '專題',
              '論文',
              '研究',
              '書報',
            ],
            memoryAvoid,
          ),
        ),
      ],
    );
  }

    _AiSearchPlan _enhancePlanWithUserPreferences(
    _AiSearchPlan plan,
    Map<String, dynamic>? userPreferences,
  ) {
    final prefs = _preferenceMap(userPreferences);
    final careerText = _careerPreferenceQuery(prefs);
    final departmentText = _departmentPreferenceQuery(prefs);
    final geText = _gePreferenceQuery(prefs);
    final memoryText = _memoryPreferenceQuery(prefs);
    final profileAvoid = _searchProfileText(
      prefs,
      const ['avoidKeywords'],
    );
    final memoryAvoid = _mergeStringLists(
      _memoryAvoidKeywords(prefs),
      _splitSearchWords(profileAvoid),
    );

    final enhancedGroups = plan.groups.map((group) {
      final bucketText = group.mustHave.join(' ').toUpperCase();
      final isCoreLike = bucketText.contains('DEPT_REQUIRED') ||
          bucketText.contains('BASIC_CORE') ||
          bucketText.contains('CORE_COURSE') ||
          bucketText.contains('PROFESSIONAL') ||
          bucketText.contains('LAB') ||
          group.requiredType == 'CORE';

      final isGeLike = bucketText.contains('GE') || group.requiredType == 'GE';

      final extra = <String>[];
      if (isCoreLike) {
        extra.addAll([departmentText, careerText, memoryText]);
      } else if (isGeLike) {
        extra.addAll([geText, memoryText]);
      } else {
        extra.addAll([departmentText, careerText, geText, memoryText]);
      }

      // User profile is advisor context, not a hard gate.
      // Do not add __BAOBAO_PREF_FIT__ here, because that can reject courses
      // the user explicitly asked for just because they do not match saved memory/profile keywords.
      return group.copyWith(
        query: [
          group.query,
          ...extra.where((item) => item.trim().isNotEmpty),
        ].join(' '),
        // For requiredType LANGUAGE, the word language is the course type/subject,
        // not instruction language. Do not apply the user's English/Chinese
        // instruction preference here unless the prompt explicitly asked it.
        language: group.requiredType == 'LANGUAGE'
            ? group.language
            : (group.language == 'any'
                ? _languagePreferenceFromPrefs(prefs)
                : group.language),
        mustHave: group.mustHave,
        avoid: _mergeStringLists(group.avoid, memoryAvoid),
      );
    }).toList();

    return _AiSearchPlan(
      targetCredits: plan.targetCredits,
      allowSpecialCourses: plan.allowSpecialCourses,
      groups: enhancedGroups,
    );
  }

  Map<String, dynamic> _memoryMap(Map<String, dynamic> prefs) {
    final rawMemory = prefs['baoBaoMemory'];
    if (rawMemory is Map) {
      return Map<String, dynamic>.from(rawMemory);
    }
    return {};
  }

  String _memoryPreferenceQuery(Map<String, dynamic> prefs) {
    final memory = _memoryMap(prefs);
    if (memory.isEmpty) return '';

    return [
      ..._stringListFromAny(memory['preferredKeywords'])
          .where((item) => !_isGenericPlanningMemoryKeyword(item)),
      ..._stringListFromAny(memory['likedCourseTitles']).take(5),
    ]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .join(' ');
  }

  bool _isGenericPlanningMemoryKeyword(String value) {
    final text = value.toLowerCase().trim();
    if (text.isEmpty) return true;

    final generic = {
      'core',
      'ge',
      'general education',
      'elective',
      'electives',
      'language',
      'course',
      'courses',
      'class',
      'classes',
      'major',
      'required',
      'requirement',
      'requirements',
      'any',
    };

    return generic.contains(text);
  }

  List<String> _memoryAvoidKeywords(Map<String, dynamic> prefs) {
    final memory = _memoryMap(prefs);
    if (memory.isEmpty) return const [];

    return [
      ..._stringListFromAny(memory['avoidKeywords']),
      ..._stringListFromAny(memory['dislikedCourseTitles']).take(8),
    ]
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Map<String, dynamic> _searchProfileMap(Map<String, dynamic> prefs) {
    final rawProfile = prefs['baoBaoSearchProfile'];

    if (rawProfile is Map) {
      return Map<String, dynamic>.from(rawProfile);
    }

    return {};
  }

  String _searchProfileText(
    Map<String, dynamic> prefs,
    List<String> keys,
  ) {
    final profile = _searchProfileMap(prefs);

    if (profile.isEmpty) {
      return '';
    }

    final keywords = <String>{};

    for (final key in keys) {
      keywords.addAll(_stringListFromAny(profile[key]));
    }

    return keywords
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .join(' ');
  }

  List<String> _splitSearchWords(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return const [];
    }

    return trimmed
        .split(RegExp(r'[,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }


  Map<String, dynamic> _preferenceMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};

    final nested = raw['preferences'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    return Map<String, dynamic>.from(raw);
  }

    String _careerPreferenceQuery(Map<String, dynamic> prefs) {
    final profileText = _searchProfileText(
      prefs,
      const [
        'careerKeywords',
        'coreCourseHints',
        'electiveHints',
      ],
    );

    if (profileText.trim().isNotEmpty) {
      return profileText;
    }

    // Fallback only: use the literal career text when the AI preference
    // resolver is unavailable. Do not hardcode career-specific mappings here.
    return _stringListFromAny(prefs['careerPaths']).join(' ');
  }

    String _departmentPreferenceQuery(Map<String, dynamic> prefs) {
    final profileText = _searchProfileText(
      prefs,
      const ['departmentKeywords'],
    );

    final hints = <String>{
      ..._splitSearchWords(profileText),
    };

    for (final entry in prefs.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('department') ||
          key.contains('dept') ||
          key.contains('major') ||
          key.contains('program')) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) hints.add(value);
      }
    }

    return hints.join(' ');
  }

    String _gePreferenceQuery(Map<String, dynamic> prefs) {
    final profileText = _searchProfileText(
      prefs,
      const ['geHints'],
    );

    return [
      profileText,
      _stringListFromAny(prefs['geInterests']).join(' '),
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }

  String _languagePreferenceFromPrefs(Map<String, dynamic> prefs) {
    final language = (prefs['languagePreference'] ?? '').toString().toLowerCase();

    if (language.contains('english')) return 'english';
    if (language.contains('chinese')) return 'chinese';

    return 'any';
  }

  List<String> _stringListFromAny(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = value.toString().trim();
    return text.isEmpty ? [] : [text];
  }

  _AiSearchPlan _buildLightEasyPlan(String message) {
    return _AiSearchPlan(
      targetCredits: null,
      allowSpecialCourses: false,
      groups: [
        _SearchGroup(
          query: 'general education GE 通識 easy light chill',
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: 8,
          credits: null,
          requiredType: 'GE',
          timePreference: 'any',
          language: 'any',
          minLimit: null,
          maxLimit: null,
          mustHave: const [],
          avoid: const [
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
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: 8,
          credits: null,
          requiredType: 'ELECTIVE',
          timePreference: 'any',
          language: 'any',
          minLimit: null,
          maxLimit: null,
          mustHave: const [],
          avoid: const [
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

  bool _isCurriculumPlanningRequest(String message) {
  final lower = message.toLowerCase();

  final talksAboutCurriculum =
      lower.contains('curriculum') ||
      lower.contains('graduation') ||
      lower.contains('requirement') ||
      lower.contains('required') ||
      lower.contains('department required') ||
      lower.contains('dept req') ||
      lower.contains('basic core') ||
      lower.contains('core course') ||
      lower.contains('professional') ||
      lower.contains('lab') ||
      lower.contains('bucket');

  final asksPlanning =
      lower.contains('plan') ||
      lower.contains('recommend') ||
      lower.contains('semester') ||
      lower.contains('credit') ||
      lower.contains('course') ||
      lower.contains('take');

  return talksAboutCurriculum && asksPlanning;
}

_AiSearchPlan _buildDynamicCurriculumPlanningPlan(
  String message,
  Map<String, dynamic> curriculum,
) {
  final lower = message.toLowerCase();
  final targetCredits = _extractTargetCreditCount(lower);

  final groupsRaw = curriculum['requirementGroups'];

  if (groupsRaw is! List) {
    return _AiSearchPlan(
      targetCredits: targetCredits,
      allowSpecialCourses: false,
      groups: const [],
    );
  }

  final dynamicGroups = <Map<String, dynamic>>[];

  for (final rawGroup in groupsRaw) {
    if (rawGroup is! Map) continue;

    final category = rawGroup['category']?.toString() ?? '';
    final description = rawGroup['description']?.toString() ?? '';
    final requiredCredits = _toInt(rawGroup['requiredCredits']);
    final coursesRaw = rawGroup['courses'];

    final bucket = _bucketFromCurriculumCategory(
      category: category,
      description: description,
    );

    final priority = curriculumBucketPlanningPriority(
      bucket: bucket,
      category: category,
      description: description,
    );

    final queryParts = <String>[
      category,
      description,
      bucket,
    ];

    if (coursesRaw is List) {
      for (final rawCourse in coursesRaw.take(30)) {
        if (rawCourse is! Map) continue;

        final name = rawCourse['name']?.toString();
        final type = rawCourse['type']?.toString();
        final acceptedCodes = rawCourse['acceptedCodes'];

        if (name != null && name.trim().isNotEmpty) {
          queryParts.add(name);
        }

        if (type != null && type.trim().isNotEmpty) {
          queryParts.add(type);
        }

        if (acceptedCodes is List) {
          for (final code in acceptedCodes) {
            queryParts.add(code.toString());
          }
        }
      }
    }

    final query = queryParts
        .where((item) => item.trim().isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (query.isEmpty) continue;

    final count = _estimateCourseCountForCurriculumGroup(
      requiredCredits: requiredCredits,
      priority: priority,
      targetCredits: targetCredits,
    );

    dynamicGroups.add({
      'priority': priority,
      'bucket': bucket,
      'query': query,
      'count': count,
      'requiredCredits': requiredCredits,
    });
  }

  dynamicGroups.sort((a, b) {
    final pa = a['priority'] as int;
    final pb = b['priority'] as int;

    if (pa != pb) {
      return pa.compareTo(pb);
    }

    final ca = a['requiredCredits'] as int;
    final cb = b['requiredCredits'] as int;

    return cb.compareTo(ca);
  });

  final selectedGroups = dynamicGroups.take(7).map((item) {
    final bucket = item['bucket']?.toString() ?? 'UNKNOWN';
    final query = item['query']?.toString() ?? '';
    final count = item['count'] as int;

    return _SearchGroup(
      query: query,
      subjectQuery: null,
      subjectPhrases: const [],
      mustMatchSubject: false,
      count: count,
      credits: null,

      // Do not rely on CORE/ELECTIVE/GE for curriculum planning.
      // Use curriculumBucket through mustHave instead.
      requiredType: bucket == 'GE' ? 'GE' : 'any',

      timePreference: 'any',
      language: 'any',
      minLimit: null,
      maxLimit: null,

      // This forces candidate pool to prefer courses mapped to this curriculum bucket.
      // Example: DEPT_REQUIRED, BASIC_CORE, CORE_COURSE, LAB, etc.
      mustHave: bucket == 'UNKNOWN' ? const [] : [bucket],

      avoid: const [
        'thesis',
        'seminar',
        'research',
        'lab rotation',
        'dissertation',
        '專題',
        '論文',
        '研究',
        '書報',
      ],
    );
  }).toList();

  return _AiSearchPlan(
    targetCredits: targetCredits,
    allowSpecialCourses: false,
    groups: selectedGroups,
  );
}

String _bucketFromCurriculumCategory({
  required String category,
  required String description,
}) {
  final text = '$category $description'.toLowerCase();

  if (text.contains('department required') ||
      text.contains('dept required') ||
      text.contains('major required') ||
      text.contains('required courses') ||
      text.contains('系定必修')) {
    return 'DEPT_REQUIRED';
  }

  if (text.contains('basic core') ||
      text.contains('basic course') ||
      text.contains('foundation') ||
      text.contains('基礎')) {
    return 'BASIC_CORE';
  }

  if (text.contains('core courses') ||
      text.contains('core course') ||
      text.contains('核心')) {
    return 'CORE_COURSE';
  }

  if (text.contains('professional') ||
      text.contains('specialized') ||
      text.contains('major elective') ||
      text.contains('專業')) {
    return 'PROFESSIONAL';
  }

  if (text.contains('lab') ||
      text.contains('laboratory') ||
      text.contains('experiment') ||
      text.contains('實驗')) {
    return 'LAB';
  }

  if (text.contains('general education') ||
      text.contains('ge') ||
      text.contains('通識')) {
    return 'GE';
  }

  if (text.contains('language') ||
      text.contains('english') ||
      text.contains('chinese') ||
      text.contains('mandarin') ||
      text.contains('英文') ||
      text.contains('中文') ||
      text.contains('華語')) {
    return 'LANGUAGE';
  }

  if (text.contains('free elective') ||
      text.contains('elective') ||
      text.contains('選修')) {
    return 'FREE_ELECTIVE';
  }

  if (text.contains('compulsory') ||
      text.contains('school required') ||
      text.contains('university required') ||
      text.contains('校定必修')) {
    return 'SCHOOL_COMPULSORY';
  }

  return 'UNKNOWN';
}

int curriculumBucketPlanningPriority({
  required String bucket,
  required String category,
  required String description,
}) {
  switch (bucket) {
    case 'DEPT_REQUIRED':
      return 1;
    case 'BASIC_CORE':
      return 2;
    case 'CORE_COURSE':
      return 3;
    case 'PROFESSIONAL':
      return 4;
    case 'LAB':
      return 5;
    case 'GE':
      return 6;
    case 'LANGUAGE':
      return 7;
    case 'SCHOOL_COMPULSORY':
      return 8;
    case 'FREE_ELECTIVE':
      return 9;
    default:
      return 99;
  }
}

int _estimateCourseCountForCurriculumGroup({
  required int requiredCredits,
  required int priority,
  required int? targetCredits,
}) {
  // For semester planning, do not try to satisfy the whole curriculum group.
  // Example: 20 credits usually means around 6–8 courses, not 17 courses.
  if (targetCredits != null && targetCredits > 0) {
    if (priority == 1) {
      return 2; // Department required
    }

    if (priority == 2) {
      return 2; // Basic core
    }

    if (priority == 3) {
      return 2; // Core courses
    }

    if (priority == 4) {
      return 1; // Professional
    }

    if (priority == 5) {
      return 1; // Lab
    }

    return 1; // GE / language / free elective
  }

  if (requiredCredits <= 0) {
    return priority <= 3 ? 3 : 2;
  }

  final estimated = (requiredCredits / 3).ceil();

  if (priority <= 3) {
    return estimated.clamp(2, 5);
  }

  if (priority <= 5) {
    return estimated.clamp(1, 3);
  }

  return estimated.clamp(1, 2);
}

bool _hasExplicitProfessorSearchIntent(String message) {
  final lower = message.toLowerCase();

  if (lower.contains('prof ') ||
      lower.contains('professor') ||
      lower.contains('teacher') ||
      lower.contains('instructor') ||
      lower.contains('taught by')) {
    return true;
  }

  final byFromWithPattern = RegExp(
    r'\b(?:class|classes|course|courses)\s+(?:by|from|with)\s+[a-zA-ZÀ-ž\u4e00-\u9fff]',
    caseSensitive: false,
  );

  return byFromWithPattern.hasMatch(message);
}

  bool _isCreditMixRequest(String message) {
  final lower = message.toLowerCase();

  return lower.contains('credit') &&
      lower.contains('ge') &&
      lower.contains('core') &&
      lower.contains('language');
}

_AiSearchPlan _buildCreditMixPlan(String message) {
  final lower = message.toLowerCase();

  final targetCredits = _extractTargetCreditCount(lower);

  final geCount = _extractCountBeforeKeyword(
    lower,
    keywordPatterns: [
      r'ge',
      r'general\s+education',
      r'通識',
    ],
    fallback: 4,
  );

  final coreCount = _extractCountBeforeKeyword(
    lower,
    keywordPatterns: [
      r'cs\s+core',
      r'eecs\s+core',
      r'core',
      r'必修',
    ],
    fallback: 2,
  );

  final languageCount = _extractCountBeforeKeyword(
    lower,
    keywordPatterns: [
      r'language',
      r'foreign\s+language',
      r'英文',
      r'日文',
      r'中文',
      r'華語',
    ],
    fallback: 1,
  );

  return _AiSearchPlan(
    targetCredits: targetCredits,
    allowSpecialCourses: false,
    groups: [
      _SearchGroup(
        query: 'general education GE 通識',
        subjectQuery: null,
        subjectPhrases: const [],
        mustMatchSubject: false,
        count: geCount,
        credits: null,
        requiredType: 'GE',
        timePreference: 'any',
        language: 'any',
        minLimit: null,
        maxLimit: null,
        mustHave: const [],
        avoid: const [],
      ),
      _SearchGroup(
        query:
            'CS EECS computer programming software algorithm data structure computer architecture operating system database 資訊 程式',
        subjectQuery: null,
        subjectPhrases: const [],
        mustMatchSubject: false,
        count: coreCount,
        credits: null,
        requiredType: 'CORE',
        timePreference: 'any',
        language: 'any',
        minLimit: null,
        maxLimit: null,
        mustHave: const [],
        avoid: const [],
      ),
      _SearchGroup(
        query: 'language English Japanese Chinese Mandarin 英文 日文 中文 華語',
        subjectQuery: 'language course',
        subjectPhrases: const [
          'language',
          'English',
          'Japanese',
          'Chinese',
          'Mandarin',
          '英文',
          '日文',
          '中文',
          '華語',
        ],
        mustMatchSubject: true,
        count: languageCount,
        credits: null,
        requiredType: 'LANGUAGE',
        timePreference: 'any',
        language: 'any',
        minLimit: null,
        maxLimit: null,
        mustHave: const [],
        avoid: const [],
      ),
    ],
  );
}

int? _extractTargetCreditCount(String lower) {
  final match = RegExp(
    r'\b([0-9]+)\s*[- ]?\s*credits?\b',
  ).firstMatch(lower);

  if (match == null) {
    return null;
  }

  return int.tryParse(match.group(1) ?? '');
}

int _extractCountBeforeKeyword(
  String lower, {
  required List<String> keywordPatterns,
  required int fallback,
}) {
  for (final keywordPattern in keywordPatterns) {
    final regex = RegExp(
      r'\b([0-9]+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(?:' +
          keywordPattern +
          r')\b',
      caseSensitive: false,
    );

    final match = regex.firstMatch(lower);

    if (match != null) {
      final raw = match.group(1) ?? '';
      return _smallNumberToInt(raw) ?? fallback;
    }
  }

  return fallback;
}

int? _smallNumberToInt(String value) {
  switch (value.toLowerCase()) {
    case '1':
    case 'one':
      return 1;
    case '2':
    case 'two':
      return 2;
    case '3':
    case 'three':
      return 3;
    case '4':
    case 'four':
      return 4;
    case '5':
    case 'five':
      return 5;
    case '6':
    case 'six':
      return 6;
    case '7':
    case 'seven':
      return 7;
    case '8':
    case 'eight':
      return 8;
    case '9':
    case 'nine':
      return 9;
    case '10':
    case 'ten':
      return 10;
    default:
      return null;
  }
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

  Future<_AiSearchPlan> _makeAiSearchPlan(
    String userMessage, {
    BaoBaoCourseIntent? intent,
    Map<String, dynamic>? userPreferences,
  }) async {
    // Prompt-first fallback: if the model cannot return a search plan, do not
    // convert the raw prompt into a strict keyword/subject search. Use the
    // prompt as a broad planning query instead.
    final fallback = _AiSearchPlan.promptFirst(userMessage);

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
- You may receive JSON containing userMessage and resolvedIntent.
- Use resolvedIntent if present.
- Priority order is strict:
  1. The user's latest prompt / resolvedIntent is the main task. Give the user what they asked for.
  2. The user's profile is advisor context only: department, career path, curriculum, language, credit target, and memory help choose among courses that fit the prompt.
  3. General quality signals like capacity, year fit, and rating are tie-breakers.
- If userProfile conflicts with the latest prompt, the latest prompt wins.
- Never change the requested topic/type/count/time/language just because old memory or profile says something else.
- If resolvedIntent.intent is direct_search, build a clean direct search plan from resolvedIntent.query and resolvedIntent.searchMode.
- If resolvedIntent.searchMode is general_plan, build broad planning groups from the student's goal; do not use mustMatchSubject, and do not treat the full sentence as an exact course title.
- For general_plan, use a mix of CORE/foundation courses, useful ELECTIVE/supporting courses, and possibly GE/context courses according to the user's wording and preferences.
- If resolvedIntent.searchMode is instructor, search by instructor/professor only; do not add GE/core/curriculum/previous-plan wording.
- If resolvedIntent.searchMode is subject, search by the subject only.
- If resolvedIntent.intent is modify_previous_plan, search only for the action subject; the app will merge it with the previous plan later.
- Never put sentences like "follow-up edit", "previous Bao-Bao plan", or "user preference" inside the course query.
- subjectQuery is the actual course/topic the user wants.
- subjectPhrases are possible title variants for that course/topic.
- mustMatchSubject is true when the user asks for a specific subject/course/topic.
- If mustMatchSubject is true, the app will reject courses that do not match subjectPhrases.
- Do not replace a specific subject request with a random course that only matches language/time/limit.

User profile rules:
- You may receive userProfile with department/program, career paths, target credits, language preference, and AI-generated profile keywords.
- User profile is SECOND priority, not the main request. Use it to make the prompt result more personalized, not to replace the prompt.
- For broad goal prompts, keep the user's stated goal as the main direction. Use department/career as academic context and tie-breakers.
- If the student says "X with a bit/little/some Y", X is primary because the prompt says so; Y is small support. The user's department/career can strengthen X if related, but must not erase X or make Y dominate.
- For mixed-interest plans, create mostly primary/prompt-matching groups and only a small supporting group for the secondary interest.
- Do not treat generic memory words such as core, GE, elective, language, course, or class as real academic interests.

Course type rules:
- requiredType can be: CORE, ELECTIVE, GE, PE, LAB, LANGUAGE, any.
- If the user explicitly asks for PE / physical education / sport, use requiredType "PE".
- If the user explicitly asks for lab / laboratory / experiment course, use requiredType "LAB".
- If the user explicitly asks for language / English / Japanese / Chinese course, use requiredType "LANGUAGE".
- If the user says "Mandarin course", "Chinese course", "中文課", or "華語課", this means a LANGUAGE course, not Chinese instruction language. Use requiredType "LANGUAGE" and language "any".
- Only use language "chinese" when the user clearly says "taught in Chinese", "conducted in Chinese", "Chinese instruction", "中文授課", or "華語授課".
- Do not collapse PE, LAB, or LANGUAGE into ELECTIVE when the user asks for them directly.
- "early morning PE course" means requiredType "PE" and timePreference "morning".
- "lab course" means requiredType "LAB".
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
- If the user describes a broad study direction, career direction, or mixed interest such as "study X with a bit of Y", this is not a specific subject lookup. Set mustMatchSubject false and create useful planning groups.
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
- Instruction language must be checked from course language/instruction metadata, not from the title.
- A course does not need the word English/Chinese in its title to count as English-taught or Chinese-taught.

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
- If the request says recommend/suggest courses but avoid early morning, no early morning, or no morning, this is a broad planning/filter request: set mustMatchSubject false, subjectQuery null, and timePreference no_morning.
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
      "requiredType": "LANGUAGE",
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
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'resolvedIntent': intent?.toJson(),
        'userProfile': _compactUserProfileForAi(userPreferences),
      })),
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

      final hasRequestedSpecialType = groups.any((group) =>
          group.requiredType == 'PE' ||
          group.requiredType == 'LAB' ||
          group.requiredType == 'LANGUAGE');

      return _AiSearchPlan(
        targetCredits: parsed['targetCredits'] == null
            ? null
            : _toInt(parsed['targetCredits']),
        allowSpecialCourses: parsed['allowSpecialCourses'] == true ||
            hasRequestedSpecialType,
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
    final requiredBucket = _requiredCurriculumBucket(group);

    final mustTokens = group.mustHave
      .where((item) => !_isCurriculumBucketName(item))
      .where((item) => !_isPlannerControlToken(item))
      .expand(_tokens)
      .toList();
    final requiresInstructorMatch = group.mustHave.any(
      (item) => item.trim().toUpperCase() == '__BAOBAO_INSTRUCTOR_MATCH__',
    );
    final instructorTokens = group.mustHave
        .where((item) => !_isCurriculumBucketName(item))
        .where((item) => !_isPlannerControlToken(item))
        .expand(_tokens)
        .toList();
    final avoidTokens = group.avoid.expand(_tokens).toList();
    final subjectPhrases = _effectiveSubjectPhrases(group);
    final scored = <_ScoredCourse>[];

    for (final course in catalog) {
      final id = course['id']?.toString() ?? '';

      if (id.isEmpty || usedIds.contains(id)) continue;

      if (course['alreadyPlanned'] == true || course['hasConflict'] == true) {
        continue;
      }

      final allowSpecialForThisGroup = allowSpecialCourses ||
          group.requiredType == 'PE' ||
          group.requiredType == 'LAB' ||
          group.requiredType == 'LANGUAGE';

      if (!_isNormalRecommendation(
        course,
        allowSpecialCourses: allowSpecialForThisGroup,
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

      if (requiredBucket != null) {
        final courseBucket =
            (course['curriculumBucket'] ?? '').toString().toUpperCase();

        final matchedBy =
            (course['curriculumMatchedBy'] ?? '').toString().toLowerCase();

        if (courseBucket != requiredBucket) {
          continue;
        }

        final importantBuckets = {
          'DEPT_REQUIRED',
          'BASIC_CORE',
          'CORE_COURSE',
          'PROFESSIONAL',
          'LAB',
        };

        // For important curriculum buckets, fallback is not enough.
        // It must come from acceptedCode or requiredName match in the curriculum.
        if (importantBuckets.contains(requiredBucket) && matchedBy == 'fallback') {
          continue;
        }
      }

      if (!_matchesTimePreference(course, group.timePreference)) {
        continue;
      }

      // IMPORTANT: requiredType LANGUAGE means the user wants a language-class
      // course card, for example Mandarin / Chinese / Japanese / English course.
      // That is different from instruction language like "taught in Chinese".
      // So do not force language-course candidates to also be Chinese-taught
      // or English-taught unless this is a non-language course request.
      final effectiveInstructionLanguage =
          group.requiredType == 'LANGUAGE' ? 'any' : group.language;

      if (!_matchesInstructionLanguage(course, effectiveInstructionLanguage)) {
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

      if (requiresInstructorMatch &&
          !_courseMatchesInstructorTokens(course, instructorTokens)) {
        continue;
      }

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

      if (_requiresPreferenceFit(group) &&
          _toInt(course['preferenceFitScore']) <= 0) {
        continue;
      }

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

      // Candidate pool is a tool, not the brain. For broad AI planning
      // groups, give the model enough real courses to reason over instead of
      // requiring raw prompt words to literally appear in every course title.
      final isBroadAiPlanningGroup = !group.mustMatchSubject &&
          !requiresInstructorMatch &&
          !group.mustHave.any((item) =>
              item.trim().toUpperCase() == '__BAOBAO_PREF_FIT__');

      final shouldInclude = group.mustMatchSubject ||
          mustTokens.isNotEmpty ||
          score > 0 ||
          hasStrongConstraint ||
          isBroadAiPlanningGroup;

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

      final aPreference = _toInt(a.course['preferenceFitScore']);
      final bPreference = _toInt(b.course['preferenceFitScore']);

      if (aPreference != bPreference) {
        return bPreference.compareTo(aPreference);
      }

      final aLimit = _toInt(a.course['limit']);
      final bLimit = _toInt(b.course['limit']);

      final aHasSeats = aLimit > 0;
      final bHasSeats = bLimit > 0;

      if (aHasSeats != bHasSeats) {
        return aHasSeats ? -1 : 1;
      }

      if (group.minLimit != null && aLimit != bLimit) {
        return bLimit.compareTo(aLimit);
      }

      if (group.maxLimit != null && aLimit != bLimit) {
        return aLimit.compareTo(bLimit);
      }

      if (aLimit != bLimit) {
        return bLimit.compareTo(aLimit);
      }

      final aCode = a.course['code']?.toString() ?? '';
      final bCode = b.course['code']?.toString() ?? '';

      return aCode.compareTo(bCode);
    });

    return scored.take(80).map((item) => item.course).toList();
  }

  bool _isCurriculumBucketName(String value) {
    final upper = value.trim().toUpperCase();

    return {
      'DEPT_REQUIRED',
      'BASIC_CORE',
      'CORE_COURSE',
      'PROFESSIONAL',
      'LAB',
      'GE',
      'LANGUAGE',
      'FREE_ELECTIVE',
      'SCHOOL_COMPULSORY',
      'UNKNOWN',
    }.contains(upper);
  }

  bool _isPlannerControlToken(String value) {
    return value.trim().toUpperCase().startsWith('__BAOBAO_');
  }

  bool _requiresPreferenceFit(_SearchGroup group) {
    return group.mustHave.any(
      (item) => item.trim().toUpperCase() == '__BAOBAO_PREF_FIT__',
    );
  }


  String? _requiredCurriculumBucket(_SearchGroup group) {
    for (final item in group.mustHave) {
      if (_isPlannerControlToken(item)) {
        continue;
      }

      final upper = item.trim().toUpperCase();

      if (_isCurriculumBucketName(upper)) {
        return upper;
      }
    }

    return null;
  }

  List<String> _effectiveSubjectPhrases(_SearchGroup group) {
    final phrases = <String>[];

    if (group.subjectQuery != null &&
        group.subjectQuery!.trim().isNotEmpty) {
      phrases.add(group.subjectQuery!.trim());
    }

    phrases.addAll(group.subjectPhrases);

    final expanded = <String>[];
    for (final phrase in phrases) {
      final trimmed = phrase.trim();
      if (trimmed.isEmpty) continue;
      expanded.add(trimmed);
      expanded.addAll(_subjectSynonymsFor(trimmed));
    }

    return expanded
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _subjectSynonymsFor(String phrase) {
    final lower = phrase.toLowerCase();
    final synonyms = <String>[];

    void addAll(List<String> values) {
      for (final value in values) {
        if (!synonyms.contains(value)) synonyms.add(value);
      }
    }

    if (lower.contains('swim') || phrase.contains('游泳')) {
      addAll(['swimming', 'swim', '游泳']);
    }
    if (lower.contains('basketball') || phrase.contains('籃球') || phrase.contains('篮球')) {
      addAll(['basketball', '籃球', '篮球']);
    }
    if (lower.contains('badminton') || phrase.contains('羽球') || phrase.contains('羽毛球')) {
      addAll(['badminton', '羽球', '羽毛球']);
    }
    if (lower.contains('volleyball') || phrase.contains('排球')) {
      addAll(['volleyball', '排球']);
    }
    if (lower.contains('tennis') || phrase.contains('網球') || phrase.contains('网球')) {
      addAll(['tennis', '網球', '网球']);
    }
    if (lower.contains('yoga') || phrase.contains('瑜伽')) {
      addAll(['yoga', '瑜伽']);
    }
    if (lower.contains('fitness') || lower.contains('physical fitness') ||
        phrase.contains('體適能') || phrase.contains('体适能')) {
      addAll(['fitness', 'physical fitness', '體適能', '体适能']);
    }
    if (lower == 'pe' || lower.contains('physical education') || phrase.contains('體育') || phrase.contains('体育')) {
      addAll(['PE', 'physical education', '體育', '体育']);
    }

    return synonyms;
  }

  bool _matchesAnySubjectPhrase(
    Map<String, dynamic> course,
    List<String> subjectPhrases,
  ) {
    if (subjectPhrases.isEmpty) {
      return true;
    }

    final courseText = _subjectSearchKey([
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['code'],
      course['id'],
    ].whereType<Object>().join(' '));

    for (final phrase in subjectPhrases) {
      final phraseText = _subjectSearchKey(phrase);

      if (phraseText.isEmpty) continue;

      if (courseText.contains(phraseText) || phraseText.contains(courseText)) {
        return true;
      }

      final phraseTokens = phraseText
          .split(' ')
          .where((item) => item.trim().isNotEmpty)
          .toList();

      if (phraseTokens.length >= 2 &&
          phraseTokens.every((token) => courseText.contains(token))) {
        return true;
      }
    }

    return false;
  }

  String _subjectSearchKey(String value) {
    var text = value.toLowerCase();

    text = text
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[\(\)\[\]\-_/,:;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Roman numerals -> numbers
    text = text
        .replaceAll(RegExp(r'\biv\b'), '4')
        .replaceAll(RegExp(r'\biii\b'), '3')
        .replaceAll(RegExp(r'\bii\b'), '2')
        .replaceAll(RegExp(r'\bi\b'), '1');

    // Chinese course numbers -> numbers
    text = text
        .replaceAll('四', '4')
        .replaceAll('三', '3')
        .replaceAll('二', '2')
        .replaceAll('一', '1');

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
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
    final promptFirstGoal = _isPromptFirstGoalGroup(group);

    final title = _looseText((course['title'] ?? '').toString());
    final code = _looseText((course['code'] ?? '').toString());
    final department = _looseText((course['department'] ?? '').toString());
    final type = _looseText((course['type'] ?? '').toString());
    final bucket = (course['curriculumBucket'] ?? 'UNKNOWN').toString();
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

      if (professor.contains(looseToken)) score += promptFirstGoal ? 80 : 170;
      if (title.contains(looseToken)) score += promptFirstGoal ? 260 : 90;
      if (code.contains(looseToken)) score += promptFirstGoal ? 120 : 80;
      if (department.contains(looseToken)) score += promptFirstGoal ? 90 : 60;
      if (type.contains(looseToken)) score += promptFirstGoal ? 40 : 50;
      if (looseText.contains(looseToken)) score += promptFirstGoal ? 80 : 30;

      if (looseToken.length >= 4) {
        for (final textToken in textTokens) {
          final looseTextToken = _looseText(textToken);

          if (looseTextToken.length < 4) continue;
          if (looseTextToken[0] != looseToken[0]) continue;

          if (_similarity(looseToken, looseTextToken) >= 0.84) {
            score += promptFirstGoal ? 35 : 12;
          }
        }
      }
    }

    score += _curriculumBucketScoreForGroup(bucket, group);

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

    score += _toInt(course['yearFitScore']);
    final preferenceScore = _toInt(course['preferenceFitScore']);
    score += promptFirstGoal ? math.min(preferenceScore, 120) : preferenceScore;

    return score;
  }

  // ============================================================
  // STEP 3: AI RERANKS REAL CANDIDATES ONLY
  // ============================================================

  Future<List<String>> _aiChooseCourseIds({
    required String userMessage,
    required _SearchGroup group,
    required List<Map<String, dynamic>> candidates,
    Map<String, dynamic>? curriculum,
    Map<String, dynamic>? userPreferences,
  }) async {
    final compactCandidates = candidates.take(120).map((course) {
      return {
        'id': course['id'],
        'code': _short(course['code'], 40),
        'title': _short(course['title'], 90),
        'professor': _short(course['professor'], 80),
        'credits': course['credits'],
        'type': course['type'],
        'curriculumBucket': course['curriculumBucket'],
        'curriculumCategory': _short(course['curriculumCategory'], 80),
        'curriculumRequiredCourseName':
            _short(course['curriculumRequiredCourseName'], 100),
        'curriculumMatchedBy': course['curriculumMatchedBy'],
        'studentYear': course['studentYear'],
        'courseYearLevel': course['courseYearLevel'],
        'yearFitScore': course['yearFitScore'],
        'preferenceFitScore': course['preferenceFitScore'],
        'preferenceReasons': course['preferenceReasons'],
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
You are Bao-Bao's course-selection brain.

You are given the user's prompt, the planner tool constraints, curriculum context,
and a real candidate list from Firestore. Think like an academic advisor and choose
only real candidate IDs.

Priority order is strict:
1. Latest user prompt: satisfy what the student asked for first.
2. User profile: use department/program/career/curriculum/language/memory to personalize and break ties.
3. General quality: year fit, capacity, rating, and balance.

If userProfile or old memory conflicts with the latest prompt, the latest prompt wins.
Do not invent course IDs. Do not use hidden assumptions. Do not rely on hardcoded
career/professor/course mappings. Use the candidate metadata.

Tool constraints are mandatory:
- Choose at most group.count IDs.
- If requiredType is GE, every selected course must have type GE / GE metadata.
- If requiredType is CORE, every selected course must have type CORE / core metadata.
- If requiredType is ELECTIVE, every selected course must have type ELECTIVE / elective metadata.
- If requiredType is PE, every selected course must be PE / physical education / sport metadata.
- If requiredType is LAB, every selected course must be LAB / laboratory / experiment metadata.
- If requiredType is LANGUAGE, every selected course must be language-course metadata.
- If mustMatchSubject is true, selected courses must match subjectQuery/subjectPhrases.
- If language/time/credits/limit constraints are present, respect them.
- Do not choose thesis, seminar, research, lab rotation, or 0-credit courses unless directly requested.
- Prefer courses that fit the user's latest prompt first, then curriculum, student year, preferences, and memory.
- Avoid time conflicts when times are visible in the candidates.

For broad goal prompts, do not require exact words in every title. Choose a balanced set that helps the user's stated goal using departments, course types, curriculum buckets, and titles.

Prompt-first profile rules:
- The prompt is priority 1. userProfile is priority 2.
- Use department/program/career/searchProfile as advisor context only after the prompt meaning is satisfied.
- If the prompt asks for a topic different from the profile, still answer the prompt; use the profile to choose the most suitable courses inside that topic.
- If the prompt says "X with a bit/little/some Y", choose mostly courses that support X. Choose only a small number that support Y. Do not let Y or old memory dominate.
- Generic memory words like core, GE, elective, language, course, or class are not real academic interests.
- If a course only matches a generic memory word, do not treat that as a strong reason.

Return JSON only:
{
  "courseIds": ["id1", "id2"]
}
''',
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'userCurriculum': _compactCurriculumForAi(curriculum),
        'userProfile': _compactUserProfileForAi(userPreferences),
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
      })),
      temperature: 0.03,
      maxTokens: 500,
    );

    if (content == null || content.trim().isEmpty) {
      return const [];
    }

    try {
      final parsed = jsonDecode(_extractJsonObject(content));
      final ids = parsed['courseIds'];

      if (ids is! List) {
        return const [];
      }

      final validIds = candidates
          .map((course) => course['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      return ids
          .map((id) => id.toString())
          .where(validIds.contains)
          .toList();
    } catch (error) {
      print('Bao-Bao AI selector parse failed: $error');
      print('Bao-Bao raw selector response: $content');
      return const [];
    }
  }

  Map<String, dynamic> _compactUserProfileForAi(
    Map<String, dynamic>? rawPreferences,
  ) {
    final prefs = _preferenceMap(rawPreferences);
    if (prefs.isEmpty) return {};

    final memory = _memoryMap(prefs);

    final departmentHints = <String>{};
    for (final entry in prefs.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('department') ||
          key.contains('dept') ||
          key.contains('major') ||
          key.contains('program')) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) departmentHints.add(value);
      }
    }

    return _jsonSafe({
      'departmentOrProgram': departmentHints.toList(),
      'careerPaths': _stringListFromAny(prefs['careerPaths']),
      'geInterests': _stringListFromAny(prefs['geInterests']),
      'targetCreditLoad': prefs['targetCreditLoad'],
      'languagePreference': prefs['languagePreference'],
      'aiSearchProfile': _searchProfileMap(prefs),
      'baoBaoMemory': {
        'preferredKeywords': _stringListFromAny(memory['preferredKeywords'])
            .where((item) => !_isGenericPlanningMemoryKeyword(item))
            .take(8)
            .toList(),
        'avoidKeywords': _stringListFromAny(memory['avoidKeywords']).take(8).toList(),
        'likedCourseTitles': _stringListFromAny(memory['likedCourseTitles']).take(5).toList(),
        'dislikedCourseTitles': _stringListFromAny(memory['dislikedCourseTitles']).take(5).toList(),
      },
    }) as Map<String, dynamic>;
  }

  Map<String, dynamic>? _compactCurriculumForAi(Map<String, dynamic>? curriculum) {
    if (curriculum == null) {
      return null;
    }

    final groupsRaw = curriculum['requirementGroups'];
    final allGroups = <Map<String, dynamic>>[];

    if (groupsRaw is List) {
      for (final group in groupsRaw) {
        if (group is! Map) continue;

        final category = group['category']?.toString() ?? '';
        final description = group['description']?.toString() ?? '';
        final coursesRaw = group['courses'];
        final compactCourses = <Map<String, dynamic>>[];

        if (coursesRaw is List) {
          for (final course in coursesRaw) {
            if (course is! Map) continue;

            compactCourses.add({
              'name': course['name'],
              'credits': course['credits'],
              'acceptedCodes': course['acceptedCodes'],
              'type': course['type'],
              'remarks': course['remarks'],
            });
          }
        }

        allGroups.add({
          'priority': _curriculumGroupPriority(category, description),
          'category': category,
          'requiredCredits': group['requiredCredits'],
          'description': description,
          'courses': compactCourses,
        });
      }
    }

    allGroups.sort((a, b) {
      final pa = a['priority'] is int ? a['priority'] as int : 999;
      final pb = b['priority'] is int ? b['priority'] as int : 999;
      return pa.compareTo(pb);
    });

    final compactGroups = allGroups.map((group) {
      final courses = group['courses'];

      return {
        'category': group['category'],
        'requiredCredits': group['requiredCredits'],
        'description': group['description'],
        'courses': courses is List ? courses.take(50).toList() : [],
      };
    }).take(12).toList();

    return {
      'programName': curriculum['programName'],
      'department': curriculum['department'],
      'entryYear': curriculum['entryYear'],
      'minimumGraduationCredits': curriculum['minimumGraduationCredits'],
      'requirementGroups': compactGroups,
      'notes': curriculum['notes'],
      'planningInstruction':
          'Prioritize Department Required, Basic Core, Core Courses, Professional, and Lab requirements before general school compulsory courses.',
    };
  }

  int _curriculumGroupPriority(String category, String description) {
    final text = '$category $description'.toLowerCase();

    if (text.contains('department required') || text.contains('系定必修')) {
      return 1;
    }

    if (text.contains('basic core') || text.contains('基礎選修')) {
      return 2;
    }

    if ((text.contains('core course') || text.contains('core courses')) &&
        !text.contains('core general') &&
        !text.contains('general education')) {
      return 3;
    }

    if (text.contains('核心選修')) {
      return 3;
    }

    if (text.contains('professional') || text.contains('專業選修')) {
      return 4;
    }

    if (text.contains('lab') ||
        text.contains('laboratory') ||
        text.contains('實驗')) {
      return 5;
    }

    if (text.contains('free elective') || text.contains('其餘選修')) {
      return 6;
    }

    if (text.contains('general education') ||
        text.contains('core general') ||
        text.contains('ge') ||
        text.contains('通識')) {
      return 7;
    }

    if (text.contains('english') ||
        text.contains('chinese') ||
        text.contains('mandarin') ||
        text.contains('language') ||
        text.contains('英文') ||
        text.contains('中文') ||
        text.contains('華語')) {
      return 8;
    }

    if (text.contains('compulsory') || text.contains('校定必修')) {
      return 9;
    }

    return 99;
  }


  bool _isPromptFirstGoalGroup(_SearchGroup group) {
    return group.mustHave.any(
      (item) => item.trim().toUpperCase() == '__BAOBAO_PROMPT_FIRST__',
    );
  }

  int _curriculumBucketScoreForGroup(String bucket, _SearchGroup group) {
    final normalizedBucket = bucket.toUpperCase();
    final requestedBuckets = group.mustHave
        .map((item) => item.toUpperCase().trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    final query = '${group.query} ${group.subjectQuery ?? ''}'.toLowerCase();

    int score = 0;

    if (_isPromptFirstGoalGroup(group)) {
      switch (normalizedBucket) {
        case 'DEPT_REQUIRED':
        case 'BASIC_CORE':
        case 'CORE_COURSE':
        case 'PROFESSIONAL':
        case 'LAB':
          return 120;
        case 'GE':
        case 'LANGUAGE':
          return 80;
        case 'FREE_ELECTIVE':
        case 'SCHOOL_COMPULSORY':
          return 40;
        default:
          return 0;
      }
    }

    // If this group specifically asks for this bucket, make it very strong.
    if (requestedBuckets.contains(normalizedBucket)) {
      score += 10000;
    }

    switch (normalizedBucket) {
      case 'DEPT_REQUIRED':
        score += 5000;
        break;
      case 'BASIC_CORE':
        score += 4500;
        break;
      case 'CORE_COURSE':
        score += 4000;
        break;
      case 'PROFESSIONAL':
        score += 2500;
        break;
      case 'LAB':
        score += 2200;
        break;
      case 'GE':
        score += 1200;
        break;
      case 'LANGUAGE':
        score += 1000;
        break;
      case 'SCHOOL_COMPULSORY':
        score += 800;
        break;
      case 'FREE_ELECTIVE':
        score += 300;
        break;
      default:
        score += 0;
    }

    if (query.contains('department') && normalizedBucket == 'DEPT_REQUIRED') {
      score += 2000;
    }

    if (query.contains('basic') && normalizedBucket == 'BASIC_CORE') {
      score += 2000;
    }

    if (query.contains('core') && normalizedBucket == 'CORE_COURSE') {
      score += 1800;
    }

    if (query.contains('professional') && normalizedBucket == 'PROFESSIONAL') {
      score += 1500;
    }

    if ((query.contains('lab') || query.contains('laboratory')) &&
        normalizedBucket == 'LAB') {
      score += 1500;
    }

    if ((query.contains('ge') || query.contains('general education')) &&
        normalizedBucket == 'GE') {
      score += 1200;
    }

    if ((query.contains('language') ||
            query.contains('english') ||
            query.contains('chinese') ||
            query.contains('mandarin')) &&
        normalizedBucket == 'LANGUAGE') {
      score += 1200;
    }

    return score;
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
              r'\b(i|hear|heard|that|class|classes|course|courses|next|semester|sem|this|conducted|conduct|taught|english|chinese|morning|night|afternoon|evening|please|pls|is|are|easy|good|nice|add|include|her|his|their|my|to|plan|schedule)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'[^a-zA-ZÀ-ž\u4e00-\u9fff]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final blockedProfessorWords = {
        'each',
        'list',
        'course',
        'courses',
        'class',
        'classes',
        'recommended',
        'recommend',
        'plan',
        'semester',
        'curriculum',
        'graduation',
        'data',
        'uploaded',
        'based',
        'prioritize',
        'missing',
        'department',
        'dept',
        'required',
        'basic',
        'core',
        'professional',
        'lab',
        'requirements',
        'before',
        'choosing',
        'duplicate',
        'sections',
        'same',
        'different',
        'easy',
        'good',
        'nice',
        'add',
        'include',
        'her',
        'his',
        'their',
        'my',
        'to',
        'plan',
        'schedule',
      };

      final tokens = _tokens(name)
          .where((token) => token.length >= 2)
          .where((token) => !blockedProfessorWords.contains(token.toLowerCase()))
          .toList();

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

  bool _courseMatchesInstructorTokens(
    Map<String, dynamic> course,
    List<String> tokens,
  ) {
    if (tokens.isEmpty) return false;

    final professorText = _looseText(
      [
        course['professor'],
        course['instructor'],
        course['teacher'],
      ].whereType<Object>().join(' '),
    );

    if (professorText.isEmpty) return false;

    return tokens.every((token) {
      final normalizedToken = _looseText(token);
      return normalizedToken.isNotEmpty &&
          professorText.contains(normalizedToken);
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

    final normalizedType = _normalizeType(
      [
        course['type'],
        course['department'],
        course['curriculumBucket'],
        course['curriculumCategory'],
        course['title'],
        course['titleZh'],
        course['titleEn'],
      ].whereType<Object>().join(' '),
    );

    // PE / LAB / LANGUAGE are normal user-requestable course types in this app.
    // They are not random special filler. Many PE courses have 0 credits or
    // missing limits, and some language/lab metadata is incomplete. Do not
    // delete them before the AI tool can choose from the real catalog.
    final isRequestedSpecialType =
        normalizedType == 'PE' || normalizedType == 'LAB' || normalizedType == 'LANGUAGE';

    final credits = _toInt(course['credits']);
    if (credits <= 0 && !isRequestedSpecialType) return false;

    final limit = _toInt(course['limit']);
    if (limit <= 0 && !isRequestedSpecialType) return false;

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

    // If the user explicitly asks for LAB, do not reject a real lab course just
    // because its title contains "experiment" / "laboratory". Still reject
    // research-style project/seminar/thesis items.
    final relaxedBadWords = normalizedType == 'LAB'
        ? badWords.where((word) => word != 'lab rotation').toList()
        : badWords;

    for (final word in relaxedBadWords) {
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
    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();
    final category = (course['curriculumCategory'] ?? '').toString().toUpperCase();
    final text = _searchText(course);
    final identityText = _normalizeSearchText([
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['department'],
      course['type'],
      course['curriculumBucket'],
      course['curriculumCategory'],
    ].whereType<Object>().join(' '));

    bool containsAny(List<String> words) {
      return words.any((word) => text.contains(word));
    }

    bool identityContainsAny(List<String> words) {
      return words.any((word) => identityText.contains(_normalizeSearchText(word)));
    }

    switch (requiredType) {
      case 'CORE':
        return type == 'CORE' ||
            bucket == 'CORE_COURSE' ||
            bucket == 'BASIC_CORE' ||
            bucket == 'DEPT_REQUIRED';

      case 'ELECTIVE':
        return type == 'ELECTIVE' || bucket == 'FREE_ELECTIVE';

      case 'GE':
        return type == 'GE' ||
            department == 'GE' ||
            bucket == 'GE' ||
            text.contains('通識') ||
            text.contains('general education');

      case 'PE':
        return type == 'PE' ||
            department == 'PE' ||
            bucket == 'PE' ||
            category == 'PE' ||
            containsAny([
              'physical education',
              'pe ',
              ' pe',
              'sports',
              'sport',
              '體育',
              '體適能',
              'basketball',
              'volleyball',
              'badminton',
              'swimming',
              'swim',
              'tennis',
              'yoga',
              'fitness',
              '游泳',
              '籃球',
              '篮球',
              '羽球',
              '羽毛球',
              '排球',
              '網球',
              '网球',
              '瑜伽',
              '體適能',
              '体适能',
            ]);

      case 'LAB':
        return type == 'LAB' ||
            bucket == 'LAB' ||
            category == 'LAB' ||
            containsAny([
              'laboratory',
              ' lab',
              'lab ',
              'experiment',
              'experimental',
              '實驗',
            ]);

      case 'LANGUAGE':
        return type == 'LANGUAGE' ||
            type == 'LANG' ||
            department == 'LANG' ||
            department == 'CLC' ||
            bucket == 'LANGUAGE' ||
            category == 'LANGUAGE' ||
            identityContainsAny([
              'language',
              'english reading',
              'english communication',
              'academic english',
              'japanese',
              'mandarin',
              'mandarin basic',
              'mandarin intermediate',
              'chinese',
              'chinese language',
              'language course',
              '華語',
              '中文',
              '英文',
              '日文',
              '語言',
              '外語',
            ]);

      default:
        return true;
    }
  }

  String _normalizeType(String value) {
    final upper = value.trim().toUpperCase();

    if (upper.contains('CORE')) return 'CORE';
    if (upper.contains('GE') || upper.contains('GENERAL')) return 'GE';
    if (upper.contains('LANG') ||
        upper.contains('CLC') ||
        upper.contains('MANDARIN') ||
        upper.contains('CHINESE LANGUAGE') ||
        upper.contains('華語') ||
        upper.contains('中文課') ||
        upper.contains('語言')) {
      return 'LANGUAGE';
    }
    if (upper.contains('LAB') ||
        upper.contains('LABORATORY') ||
        upper.contains('EXPERIMENT')) {
      return 'LAB';
    }
    if (upper == 'PE' ||
        upper.contains('PHYSICAL') ||
        upper.contains('SPORT') ||
        upper.contains('SWIMMING') ||
        upper.contains('SWIM') ||
        upper.contains('BASKETBALL') ||
        upper.contains('VOLLEYBALL') ||
        upper.contains('BADMINTON') ||
        upper.contains('TENNIS') ||
        upper.contains('YOGA') ||
        upper.contains('FITNESS') ||
        upper.contains('體育') ||
        upper.contains('体育') ||
        upper.contains('游泳') ||
        upper.contains('籃球') ||
        upper.contains('篮球') ||
        upper.contains('羽球') ||
        upper.contains('羽毛球') ||
        upper.contains('排球') ||
        upper.contains('網球') ||
        upper.contains('网球') ||
        upper.contains('瑜伽') ||
        upper.contains('體適能') ||
        upper.contains('体适能')) {
      return 'PE';
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

    if (lower.contains('early') || lower.contains('morning')) return 'morning';
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

    final languageText = _courseInstructionLanguageText(course);

    if (languageText.isEmpty) {
      return false;
    }

    if (language == 'english') {
      return _hasEnglishInstructionText(languageText);
    }

    if (language == 'chinese') {
      return _hasChineseInstructionText(languageText);
    }

    return true;
  }

  String _courseInstructionLanguageText(Map<String, dynamic> course) {
    // Important: language filtering should use instruction-language metadata,
    // not the course title. Example: a course can be taught in English even
    // when the title itself does not contain the word English.
    return [
      course['language'],
      course['instructionLanguage'],
      course['languageOfInstruction'],
      course['languageOfInstructionDescription'],
      course['teachingLanguage'],
      course['courseLanguage'],
      course['mediumOfInstruction'],
      course['conductLanguage'],
      course['taughtIn'],
      course['remarks'],
      course['note'],
    ]
        .whereType<Object>()
        .map((item) => item.toString())
        .join(' ')
        .toLowerCase()
        .trim();
  }

  bool _hasEnglishInstructionText(String text) {
    final normalized = text.toLowerCase();

    return normalized.contains('english') ||
        normalized.contains('english-taught') ||
        normalized.contains('taught in english') ||
        normalized.contains('conducted in english') ||
        RegExp(r'(^|[^a-z])(eng|en|e)([^a-z]|$)').hasMatch(normalized) ||
        normalized.contains('英文') ||
        normalized.contains('英語') ||
        normalized.contains('英授') ||
        RegExp(r'(^|[^\u4e00-\u9fff])英([^\u4e00-\u9fff]|$)')
            .hasMatch(normalized);
  }

  bool _hasChineseInstructionText(String text) {
    final normalized = text.toLowerCase();

    return normalized.contains('chinese') ||
        normalized.contains('mandarin') ||
        normalized.contains('taught in chinese') ||
        normalized.contains('conducted in chinese') ||
        RegExp(r'(^|[^a-z])(zh|zht|zhs|cn|ch|c)([^a-z]|$)')
            .hasMatch(normalized) ||
        normalized.contains('中文') ||
        normalized.contains('華語') ||
        normalized.contains('國語') ||
        normalized.contains('漢語') ||
        normalized.contains('中授') ||
        RegExp(r'(^|[^\u4e00-\u9fff])中([^\u4e00-\u9fff]|$)')
            .hasMatch(normalized);
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
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
      course['curriculumMatchedBy'],
      course['department'],
      course['slotCode'],
      course['timeSlot'],
      course['location'],
      course['language'],
      course['instructionLanguage'],
      course['languageOfInstruction'],
      course['preferenceFitScore'],
      course['preferenceReasons'],
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

  factory _AiSearchPlan.promptFirst(String message) {
    final requestedType = _extractRequiredType(message);

    return _AiSearchPlan(
      targetCredits: null,
      allowSpecialCourses: requestedType == 'PE' ||
          requestedType == 'LAB' ||
          requestedType == 'LANGUAGE',
      groups: [
        _SearchGroup(
          query: message,
          subjectQuery: null,
          subjectPhrases: const [],
          mustMatchSubject: false,
          count: _extractCount(message),
          credits: null,
          requiredType: requestedType,
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

  static String _extractRequiredType(String message) {
    final lower = message.toLowerCase();

    if (RegExp(r'\b(pe|physical education|sport|sports|basketball|volleyball|badminton|swimming|swim|tennis|yoga|fitness)\b').hasMatch(lower) ||
        lower.contains('體育') ||
        lower.contains('体育') ||
        lower.contains('游泳') ||
        lower.contains('籃球') ||
        lower.contains('篮球') ||
        lower.contains('羽球') ||
        lower.contains('羽毛球') ||
        lower.contains('排球') ||
        lower.contains('網球') ||
        lower.contains('网球') ||
        lower.contains('瑜伽') ||
        lower.contains('體適能') ||
        lower.contains('体适能')) {
      return 'PE';
    }

    if (RegExp(r'\b(lab|laboratory|experiment|experimental)\b').hasMatch(lower) ||
        lower.contains('實驗')) {
      return 'LAB';
    }

    final asksInstructionLanguage = _extractLanguagePreference(message) != 'any';

    final asksLanguageCourse =
        RegExp(r'\b(language|foreign language|english course|english class|japanese|japanese course|japanese class|mandarin|mandarin course|mandarin class|chinese course|chinese class|chinese language)\b')
                .hasMatch(lower) ||
            lower.contains('華語') ||
            lower.contains('華語課') ||
            lower.contains('中文課') ||
            lower.contains('日文') ||
            lower.contains('日文課') ||
            lower.contains('英文課') ||
            lower.contains('語言課') ||
            lower.contains('外語');

    if (asksLanguageCourse && !asksInstructionLanguage) {
      return 'LANGUAGE';
    }

    if (RegExp(r'\bge\b').hasMatch(lower) || lower.contains('general education') || lower.contains('通識')) {
      return 'GE';
    }

    if (RegExp(r'\bcore\b').hasMatch(lower)) {
      return 'CORE';
    }

    if (RegExp(r'\belective\b').hasMatch(lower) || lower.contains('選修')) {
      return 'ELECTIVE';
    }

    return 'any';
  }

  factory _AiSearchPlan.local(String message) {
    final isBroadFilterOrPlan = _isBroadFilterOrPlanningMessage(message);
    final subjectQuery = isBroadFilterOrPlan ? null : _extractLocalSubjectQuery(message);
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
          requiredType: _extractRequiredType(message),
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

  static bool _isBroadFilterOrPlanningMessage(String message) {
    final lower = message.toLowerCase();

    final hasPlanningWord = lower.contains('recommend') ||
        lower.contains('suggest') ||
        lower.contains('plan') ||
        lower.contains('course') ||
        lower.contains('courses') ||
        lower.contains('class') ||
        lower.contains('classes');

    final hasOnlyFilter = lower.contains('morning') ||
        lower.contains('afternoon') ||
        lower.contains('evening') ||
        lower.contains('night') ||
        lower.contains('credit') ||
        lower.contains('limit') ||
        lower.contains('capacity') ||
        lower.contains('conducted in') ||
        lower.contains('taught in') ||
        lower.contains('in english') ||
        lower.contains('in chinese') ||
        lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('light');

    final hasSpecificLookup = lower.contains('linear algebra') ||
        lower.contains('calculus') ||
        lower.contains('i2p') ||
        lower.contains('database') ||
        lower.contains('operating system') ||
        lower.contains('data structure') ||
        lower.contains('professor') ||
        lower.contains('taught by');

    return hasPlanningWord && hasOnlyFilter && !hasSpecificLookup;
  }

  static String _extractTimePreference(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('no morning') ||
        lower.contains('not morning') ||
        lower.contains('avoid morning') ||
        lower.contains('no early')) {
      return 'no_morning';
    }

    if (lower.contains('early') || lower.contains('morning')) return 'morning';
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
      r'\brecommend\b',
      r'\bsuggest\b',
      r'\bavoid\b',
      r'\bearly\b',
      r'\blate\b',
      r'\bbut\b',
      r'\band\b',
      r'\bor\b',
      r'\bnot\b',
      r'\bno\b',
      r'\bpreference\b',
      r'\bpreferences\b',
    ];

    for (final pattern in removePatterns) {
      text = text.replaceAll(RegExp(pattern), ' ');
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.length < 2) {
      return null;
    }

    final tokens = text.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    const genericTokens = {
      'recommend',
      'suggest',
      'avoid',
      'early',
      'late',
      'but',
      'and',
      'or',
      'not',
      'no',
      'preference',
      'preferences',
      'filter',
    };

    if (tokens.isNotEmpty && tokens.every(genericTokens.contains)) {
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
      'mustHave': mustHave
          .where((item) => !item.trim().toUpperCase().startsWith('__BAOBAO_'))
          .toList(),
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