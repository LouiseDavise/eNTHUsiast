import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

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
      memoryUpdate: rawMemory is Map ? Map<String, dynamic>.from(rawMemory) : null,
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
  bool get isClarificationNeeded => needsClarification || intent == 'clarification_needed';
  bool get isSmallTalk => intent == 'small_talk';

  List<String> get avoidKeywords {
    final value = memoryUpdate?['avoidKeywords'];
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  List<String> get preferredKeywords {
    final value = memoryUpdate?['preferredKeywords'];
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  @override
  String toString() => toJson().toString();
}

class BaoBaoAiApi {
  final Map<String, List<String>> _lastReasonsByCourseId = {};
  String _lastPlanSummary = '';
  String? _lastClarifyingQuestion;
  Map<String, dynamic> _lastToolPlan = {};

  Map<String, List<String>> get lastReasonsByCourseId => Map.unmodifiable(_lastReasonsByCourseId);
  String get lastPlanSummary => _lastPlanSummary;
  String? get lastClarifyingQuestion => _lastClarifyingQuestion;
  Map<String, dynamic> get lastToolPlan => Map.unmodifiable(_lastToolPlan);

  Future<String?> _callAiChat({
    required String systemPrompt,
    required String userContent,
    double temperature = 0.12,
    int maxTokens = 1800,
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
        if (content != null && content.isNotEmpty) return content;
      }
      return null;
    } catch (error) {
      print('Bao-Bao Firebase OpenAI call failed: $error');
      return null;
    }
  }

  Future<String> askBaoBao(String userMessage) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao, a cute panda AI assistant inside an NTHU course planner app.
Reply shortly and naturally.
Do not invent course codes.
When course cards are needed, say you can use the course-planning tools.
''',
      userContent: userMessage,
      temperature: 0.7,
      maxTokens: 250,
    );

    return content ?? 'Bao-Bao is having trouble connecting right now. Please try again.';
  }

  Future<Map<String, dynamic>> buildBaoBaoPreferenceSearchProfile({
    required Map<String, dynamic>? userPreferences,
  }) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's profile understanding tool.
Return JSON only. Do not recommend course IDs.
Summarize the user's profile in a flexible way. Do not use hardcoded career mappings.
Schema:
{
  "profileSummary": "",
  "academicDirection": [],
  "preferenceNotes": [],
  "avoidNotes": []
}
''',
      userContent: jsonEncode(_jsonSafe({'userPreferences': userPreferences ?? {}})),
      temperature: 0.05,
      maxTokens: 500,
    );

    if (content == null || content.trim().isEmpty) return {};
    try {
      final parsed = jsonDecode(_extractJsonObject(content));
      return parsed is Map ? Map<String, dynamic>.from(parsed) : {};
    } catch (_) {
      return {};
    }
  }

  Future<BaoBaoCourseIntent> understandBaoBaoCourseIntent({
    required String userMessage,
    required List<String> lastRecommendationIds,
    required List<String> plannedCourseIds,
    Map<String, dynamic>? userPreferences,
  }) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's intent understanding agent.
Return JSON only. Do not recommend courses here.

Priority:
1. Latest user prompt is the highest priority.
2. User profile/curriculum/memory/current plan are background context only.
3. Never replace the user's explicit request with saved profile.

Understand the message naturally. Do not use hardcoded examples. Do not require exact English words.
If the request is clear enough to search or plan, do not ask clarification.
Ask clarification only when the request is impossible to act on safely.

Schema:
{
  "intent": "new_plan | direct_search | modify_previous_plan | memory_update | clear_memory | small_talk | clarification_needed",
  "basePlan": "none | current_plan | last_recommendation",
  "usePreviousRecommendation": false,
  "searchMode": "general_plan | subject | instructor | time | course_type | credit_mix | unknown",
  "query": "faithful natural-language version of the user's request",
  "actions": [],
  "memoryUpdate": {"avoidKeywords": [], "preferredKeywords": []},
  "needsClarification": false,
  "clarifyingQuestion": null
}
''',
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'lastRecommendationIds': lastRecommendationIds,
        'plannedCourseIds': plannedCourseIds,
        'userPreferences': userPreferences ?? {},
      })),
      temperature: 0.05,
      maxTokens: 650,
    );

    if (content == null || content.trim().isEmpty) {
      return _fallbackIntent(userMessage);
    }

    try {
      final parsed = jsonDecode(_extractJsonObject(content));
      if (parsed is Map) {
        return BaoBaoCourseIntent.fromJson(Map<String, dynamic>.from(parsed));
      }
    } catch (error) {
      print('Bao-Bao intent JSON parse failed: $error');
      print('Bao-Bao raw intent response: $content');
    }

    return _fallbackIntent(userMessage);
  }

  Future<List<String>> askBaoBaoRecommendedCourseIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
    Map<String, dynamic>? curriculum,
    Map<String, dynamic>? userPreferences,
    BaoBaoCourseIntent? intent,
  }) async {
    _lastReasonsByCourseId.clear();
    _lastPlanSummary = '';
    _lastClarifyingQuestion = null;
    _lastToolPlan = {};

    final courseTools = courseCatalog.map(_courseToolRecord).where((course) {
      return (course['id'] ?? '').toString().trim().isNotEmpty;
    }).toList();

    if (courseTools.isEmpty) {
      _lastClarifyingQuestion = 'Bao-Bao has no real course cards available to use.';
      return const [];
    }

    final aliasToId = _courseAliasToId(courseTools);
    final courseById = <String, Map<String, dynamic>>{};
    for (final course in courseCatalog) {
      for (final key in _courseAliasKeys(course)) {
        courseById[key] = course;
      }
    }
    courseById.removeWhere((key, value) => key.isEmpty);

    final toolPlan = await _askAgentForToolPlan(
      userMessage: userMessage,
      courseTools: courseTools,
      curriculum: curriculum,
      userPreferences: userPreferences,
      intent: intent,
    );
    _lastToolPlan = toolPlan;

    final candidates = _retrieveCandidatesFromToolPlan(
      userMessage: userMessage,
      toolPlan: toolPlan,
      courseTools: courseTools,
      maxCandidates: 180,
    );

    var candidatePool = List<Map<String, dynamic>>.from(candidates);

    print('Bao-Bao AI tool plan: $toolPlan');
    print('Bao-Bao tool candidates: ${candidatePool.length} / ${courseTools.length}');

    // Agentic rescue retrieval:
    // Dart does not encode PE/Mandarin/GE/etc. synonyms here. If the first AI
    // search plan is too narrow, Bao-Bao scans real course-tool batches with AI
    // and asks the model itself which cards may match the prompt.
    if (candidatePool.length < 25) {
      final scannedCandidates = await _aiScanCandidateBatches(
        userMessage: userMessage,
        courseTools: courseTools,
        curriculum: curriculum,
        userPreferences: userPreferences,
        intent: intent,
        toolPlan: toolPlan,
        aliasToId: aliasToId,
      );
      candidatePool = _mergeCandidateRecords(candidatePool, scannedCandidates);
      print('Bao-Bao AI batch-scan candidates: ${candidatePool.length} / ${courseTools.length}');
    }

    if (candidatePool.isEmpty) {
      // Last resort: give Bao-Bao a broad real-course tool sample instead of
      // returning zero before AI can reason.
      candidatePool = courseTools
          .where((course) => course['completedOrInProgress'] != true)
          .map(_candidateCourseRecord)
          .take(160)
          .toList();
    }

    var selectedIds = await _askAgentAndReadIds(
      userMessage: userMessage,
      courseTools: candidatePool,
      curriculum: curriculum,
      userPreferences: userPreferences,
      intent: intent,
      toolPlan: toolPlan,
      toolFeedback: const [],
      aliasToId: aliasToId,
    );

    var feedback = _validateAiSelection(
      selectedIds: selectedIds,
      courseById: courseById,
      toolPlan: toolPlan,
    );

    for (var attempt = 0; attempt < 3 && feedback.isNotEmpty; attempt++) {
      print('Bao-Bao tool feedback attempt $attempt: $feedback');

      final repairedIds = await _askAgentAndReadIds(
        userMessage: userMessage,
        courseTools: candidatePool,
        curriculum: curriculum,
        userPreferences: userPreferences,
        intent: intent,
        toolPlan: toolPlan,
        toolFeedback: feedback,
        aliasToId: aliasToId,
      );

      if (repairedIds.isEmpty) break;
      selectedIds = repairedIds;
      feedback = _validateAiSelection(
        selectedIds: selectedIds,
        courseById: courseById,
        toolPlan: toolPlan,
      );
    }

    var safeIds = _safelyKeepValidAiIds(
      selectedIds: selectedIds,
      courseById: courseById,
    );

    // If AI understood but the chosen IDs were not displayable, do one full
    // AI scanner rescue pass. Dart still does not choose courses by itself.
    if (safeIds.isEmpty) {
      final scannedCandidates = await _aiScanCandidateBatches(
        userMessage: userMessage,
        courseTools: courseTools,
        curriculum: curriculum,
        userPreferences: userPreferences,
        intent: intent,
        toolPlan: toolPlan,
        aliasToId: aliasToId,
      );

      final rescuePool = _mergeCandidateRecords(candidatePool, scannedCandidates);
      if (rescuePool.isNotEmpty) {
        selectedIds = await _askAgentAndReadIds(
          userMessage: userMessage,
          courseTools: rescuePool,
          curriculum: curriculum,
          userPreferences: userPreferences,
          intent: intent,
          toolPlan: toolPlan,
          toolFeedback: const [
            'Previous answer produced no displayable course cards. Choose real IDs/codes from candidateCourses, even if only closest matches exist.',
          ],
          aliasToId: aliasToId,
        );
        safeIds = _safelyKeepValidAiIds(
          selectedIds: selectedIds,
          courseById: courseById,
        );
      }
    }

    final finalFeedback = _validateAiSelection(
      selectedIds: safeIds,
      courseById: courseById,
      toolPlan: toolPlan,
    );

    if (safeIds.isNotEmpty && finalFeedback.isNotEmpty) {
      final broadPool = _mergeCandidateRecords(
        candidatePool,
        courseTools
            .where((course) => course['completedOrInProgress'] != true)
            .map(_candidateCourseRecord)
            .take(220)
            .toList(),
      );

      final repairedIds = await _askAgentAndReadIds(
        userMessage: userMessage,
        courseTools: broadPool,
        curriculum: curriculum,
        userPreferences: userPreferences,
        intent: intent,
        toolPlan: toolPlan,
        toolFeedback: finalFeedback,
        aliasToId: aliasToId,
      );

      final repairedSafeIds = _safelyKeepValidAiIds(
        selectedIds: repairedIds,
        courseById: courseById,
      );

      if (repairedSafeIds.isNotEmpty) {
        safeIds = repairedSafeIds;
      }
    }

    safeIds = _fillCreditGapWithValidCourses(
      selectedIds: safeIds,
      preferredCandidates: _mergeCandidateRecords(
        candidatePool,
        courseTools
            .where((course) => course['completedOrInProgress'] != true)
            .map(_candidateCourseRecord)
            .toList(),
      ),
      courseById: courseById,
      toolPlan: toolPlan,
    );

    return safeIds;
  }

  Future<Map<String, dynamic>> _askAgentForToolPlan({
    required String userMessage,
    required List<Map<String, dynamic>> courseTools,
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? userPreferences,
    required BaoBaoCourseIntent? intent,
  }) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao's tool-planning agent.
Return JSON only.

You do NOT choose courses yet. You decide how to use the real course-search tool.
Dart does not know academic synonyms. If the user asks for something that may appear in Chinese or English course names, YOU must provide the search terms/synonyms in searchTerms.
Do not use fixed examples as answers. Use your own understanding of the latest user prompt.

Priority:
1. Latest user prompt is 70% of the decision.
2. User profile/curriculum/memory is 30% and only helps choose inside the requested direction.
3. General quality.

Critical rule:
- If the latest prompt explicitly names a field/area/topic, that field is the main target. Do NOT replace it with the user's saved department, career path, or old preferences.
- Example behavior: if the prompt asks for computer science, search for computing/software/algorithm/programming/database/OS/network style courses first. Do not drift back to EE/hardware unless the user asks EE or the course is clearly computing-related.

Return this schema:
{
  "goalSummary": "short interpretation of latest prompt",
  "targetCount": null,
  "targetCreditsMin": null,
  "targetCreditsMax": null,
  "candidateGroups": [
    {
      "label": "main",
      "count": null,
      "searchTerms": [],
      "excludeTerms": [],
      "notes": ""
    }
  ],
  "globalSearchTerms": [],
  "importantConstraints": [],
  "needsClarification": false,
  "clarifyingQuestion": null
}

Rules:
- searchTerms are words/phrases to search in course title, Chinese title, department, type, category, professor, time, location, language, and remarks.
- Include multilingual terms yourself when useful.
- For a broad semester plan, searchTerms can be broad or empty; Bao-Bao will receive a broad candidate sample.
- If the user asks for a mix, use multiple candidateGroups.
- If the user asks for exact number, set targetCount.
- If the user asks for credits, set targetCreditsMin and targetCreditsMax.
- For "20 credits", "20-credit semester", or similar, treat it as a credit RANGE goal, not a course-count goal. Use targetCreditsMin around 18 and targetCreditsMax around 22 unless the user says exactly.
- If the prompt asks for a full semester plan, candidateGroups should be broad enough to find many real courses, not only 3 or 4.
- If the prompt asks for chill/easy/light courses, interpret it as low-workload preference. Prefer real course cards that look like GE/elective/non-core/general interest, regular lecture, normal credits, and larger capacity. Avoid research, thesis, seminar, lab rotation, heavy lab/project, highly technical core courses, and difficult major requirements unless the user explicitly asks. If no difficulty metadata exists, explain that this is an estimated low-workload match.
- If the prompt asks for PE/sports/language/GE/lab, use your own multilingual understanding to put useful terms in searchTerms; do not rely on Dart to know synonyms.
''',
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'intent': intent?.toJson(),
        'userProfile': userPreferences ?? {},
        'curriculum': curriculum ?? {},
        'catalogStats': _catalogStats(courseTools),
        'catalogPreview': courseTools.take(25).toList(),
      })),
      temperature: 0.08,
      maxTokens: 1100,
    );

    if (content == null || content.trim().isEmpty) {
      return _defaultToolPlan(userMessage);
    }

    try {
      final parsed = jsonDecode(_extractJsonObject(content));
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (error) {
      print('Bao-Bao tool plan JSON parse failed: $error');
      print('Bao-Bao raw tool plan response: $content');
    }

    return _defaultToolPlan(userMessage);
  }

  Future<List<Map<String, dynamic>>> _aiScanCandidateBatches({
    required String userMessage,
    required List<Map<String, dynamic>> courseTools,
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? userPreferences,
    required BaoBaoCourseIntent? intent,
    required Map<String, dynamic> toolPlan,
    required Map<String, String> aliasToId,
  }) async {
    final foundIds = <String>[];
    const chunkSize = 110;
    final maxChunks = (courseTools.length + chunkSize - 1) ~/ chunkSize;

    for (var start = 0, chunkIndex = 0;
        start < courseTools.length && chunkIndex < maxChunks;
        start += chunkSize, chunkIndex++) {
      final chunk = courseTools
          .skip(start)
          .take(chunkSize)
          .map(_candidateCourseRecord)
          .toList();

      if (chunk.isEmpty) continue;

      final content = await _callAiChat(
        systemPrompt: '''
You are Bao-Bao's course-tool scanner.
Return JSON only.

You receive ONE batch of real course cards. Decide which cards in this batch may help answer the latest user prompt.
This is not the final answer. Be generous: include exact matches and useful close matches.
Use your own understanding of languages, sports, departments, course categories, time, professors, and user goals.
Do not invent IDs. Only return ids/codes that appear in this batch.

Return:
{
  "candidateIds": [],
  "scanNote": "short reason"
}
''',
        userContent: jsonEncode(_jsonSafe({
          'userMessage': userMessage,
          'intent': intent?.toJson(),
          'toolPlan': toolPlan,
          'userProfile': userPreferences ?? {},
          'curriculum': curriculum ?? {},
          'courseBatchIndex': chunkIndex,
          'courseBatch': chunk,
        })),
        temperature: 0.08,
        maxTokens: 900,
      );

      if (content == null || content.trim().isEmpty) continue;

      try {
        final parsed = jsonDecode(_extractJsonObject(content));
        if (parsed is! Map) continue;
        final rawIds = parsed['candidateIds'];
        if (rawIds is! Iterable) continue;

        for (final item in rawIds) {
          final rawId = item.toString().trim();
          if (rawId.isEmpty) continue;
          final canonical = aliasToId[rawId] ??
              aliasToId[rawId.toLowerCase()] ??
              aliasToId[_aliasKey(rawId)];
          if (canonical == null || canonical.isEmpty) continue;
          if (!foundIds.contains(canonical)) foundIds.add(canonical);
        }
      } catch (error) {
        print('Bao-Bao batch scanner parse failed: $error');
        print('Bao-Bao raw batch scanner response: $content');
      }
    }

    final byId = {
      for (final course in courseTools) (course['id'] ?? '').toString(): course,
    }..removeWhere((key, value) => key.isEmpty);

    return foundIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .map(_candidateCourseRecord)
        .toList();
  }

  List<Map<String, dynamic>> _mergeCandidateRecords(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    void add(Map<String, dynamic> course) {
      final id = (course['id'] ?? course['code'] ?? '').toString().trim();
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      merged.add(course);
    }

    for (final course in a) add(course);
    for (final course in b) add(course);
    return merged;
  }

  Future<List<String>> _askAgentAndReadIds({
    required String userMessage,
    required List<Map<String, dynamic>> courseTools,
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? userPreferences,
    required BaoBaoCourseIntent? intent,
    required Map<String, dynamic> toolPlan,
    required List<String> toolFeedback,
    required Map<String, String> aliasToId,
  }) async {
    final content = await _callAiChat(
      systemPrompt: '''
You are Bao-Bao, an autonomous course-planning agent.

You are given tool outputs as JSON:
- candidateCourses: real course cards from Firestore selected by the tool plan
- curriculum: uploaded curriculum, if any
- userProfile: profile, memory, completed/in-progress hints, and preferences
- intent: intent resolver output
- toolPlan: your own search/tool plan
- toolFeedback: validation results from previous attempt, if any

Your job:
1. Understand the latest user prompt yourself.
2. Choose the real candidate course cards that answer the prompt.
3. Never invent course IDs; use id or code exactly from candidateCourses.
4. Latest user prompt is priority #1 and should control about 70% of the decision. User profile/curriculum/memory is priority #2 and should only control about 30% as a tie-breaker.
5. If the prompt asks for a field/area/topic, choose courses in that field even if the saved profile points to a different department/career.
6. Mandarin/Chinese/Japanese/English can mean a LANGUAGE COURSE when the user asks for a course/class to study; only treat it as instruction-language when the user says taught in / conducted in / instruction language.
7. Avoid schedule conflicts unless the user explicitly allows conflicts.
8. Avoid completed or in-progress courses when the tool data says they are completed/in-progress.
9. If no exact match exists, choose the closest real cards and explain the limitation. Ask clarification only if no useful real card exists.
10. If toolPlan has targetCreditsMin/targetCreditsMax, select enough non-conflicting courses to reach at least targetCreditsMin while staying near targetCreditsMax. Do not stop at 3-4 courses if total credits are still below targetCreditsMin. For a 20-credit plan, normally select around 6-8 courses depending on credits.
11. If the user asks for a chill/easy/light plan, choose lower-workload-looking real cards: mostly GE/elective/general-interest classes, avoid technical core, lab/research/seminar/thesis/project-heavy courses unless explicitly requested.
12. If the user asks for PE/sport/language/GE/lab, satisfy that request directly from candidateCourses before adding filler courses.

Return JSON only:
{
  "selectedCourseIds": [],
  "courseReasons": {
    "courseId": ["reason 1", "reason 2"]
  },
  "planSummary": "short explanation",
  "needsClarification": false,
  "clarifyingQuestion": null
}
''',
      userContent: jsonEncode(_jsonSafe({
        'userMessage': userMessage,
        'intent': intent?.toJson(),
        'toolPlan': toolPlan,
        'curriculum': curriculum ?? {},
        'userProfile': userPreferences ?? {},
        'toolFeedback': toolFeedback,
        'candidateCourses': courseTools,
      })),
      temperature: toolFeedback.isEmpty ? 0.1 : 0.03,
      maxTokens: 2500,
    );

    if (content == null || content.trim().isEmpty) return const [];

    try {
      final parsed = jsonDecode(_extractJsonObject(content));
      if (parsed is Map) {
        final map = Map<String, dynamic>.from(parsed);
        _readAgentNotes(map, aliasToId);
        return _readSelectedIds(map, aliasToId);
      }
    } catch (error) {
      print('Bao-Bao agent selection JSON parse failed: $error');
      print('Bao-Bao raw selection response: $content');
    }

    return const [];
  }

  Map<String, dynamic> _courseToolRecord(Map<String, dynamic> course) {
    String readAny(List<String> keys) {
      for (final key in keys) {
        final value = course[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    final id = readAny(['id', 'courseId', 'docId', 'code', 'courseCode']);
    final code = readAny(['code', 'courseCode', 'id']);

    return {
      'id': id,
      'code': code,
      'title': readAny(['title', 'titleEn', 'name', 'courseName']),
      'titleZh': readAny(['titleZh', 'chineseTitle', 'nameZh', 'titleChinese']),
      'department': readAny(['department', 'dept', 'departmentCode']),
      'type': readAny(['type', 'courseType', 'category', 'curriculumBucket']),
      'credits': course['credits'],
      'professor': readAny(['professor', 'teacher', 'instructor']),
      'time': readAny(['slotCode', 'timeSlot', 'time', 'classTime']),
      'day': course['day'],
      'startSlot': course['startSlot'],
      'duration': course['duration'],
      'location': readAny(['place', 'location', 'classroom', 'room']),
      'language': readAny([
        'language',
        'instructionLanguage',
        'languageOfInstruction',
        'teachingLanguage',
        'courseLanguage',
      ]),
      'limit': course['limit'],
      'remarks': readAny(['remarks', 'note', 'description', 'summary']),
      'curriculumBucket': readAny(['curriculumBucket', 'curriculumCategory']),
      'curriculumRequiredName': readAny(['curriculumRequiredCourseName']),
      'completedOrInProgress': course['baoBaoCompletedOrInProgress'] == true,
      'searchText': _searchableCourseText(course),
    };
  }

  Map<String, String> _courseAliasToId(List<Map<String, dynamic>> courseTools) {
    final map = <String, String>{};

    void addAlias(String alias, String id) {
      final trimmed = alias.trim();
      if (trimmed.isEmpty || id.trim().isEmpty) return;
      map[trimmed] = id;
      map[trimmed.toLowerCase()] = id;
      map[_aliasKey(trimmed)] = id;

      final withoutSemester = _removeSemesterPrefix(_aliasKey(trimmed));
      if (withoutSemester.length >= 5) map[withoutSemester] = id;

      for (final short in _shortCourseCodeAliases(trimmed)) {
        map[short] = id;
        map[short.toLowerCase()] = id;
        map[_aliasKey(short)] = id;
      }
    }

    for (final course in courseTools) {
      final id = (course['id'] ?? '').toString().trim();
      final code = (course['code'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      addAlias(id, id);
      if (code.isNotEmpty) addAlias(code, id);
    }
    return map;
  }

  List<String> _courseAliasKeys(Map<String, dynamic> course) {
    final keys = <String>{};
    for (final raw in [
      course['id'],
      course['courseId'],
      course['docId'],
      course['code'],
      course['courseCode'],
    ]) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      keys.add(value);
      keys.add(value.toLowerCase());
      keys.add(_aliasKey(value));
      final withoutSemester = _removeSemesterPrefix(_aliasKey(value));
      if (withoutSemester.length >= 5) keys.add(withoutSemester);
      keys.addAll(_shortCourseCodeAliases(value));
    }
    return keys.where((key) => key.trim().isNotEmpty).toList();
  }

  List<String> _shortCourseCodeAliases(String value) {
    final compact = _aliasKey(value);
    final aliases = <String>[];

    void add(String alias) {
      if (alias.length >= 5 && !aliases.contains(alias)) aliases.add(alias);
    }

    add(compact);
    final noSemester = _removeSemesterPrefix(compact);
    add(noSemester);

    final match = RegExp(r'^([a-z]{2,6})(\d{3})\d*$').firstMatch(noSemester);
    if (match != null) {
      add('${match.group(1)}${match.group(2)}');
    }

    return aliases;
  }

  String _canonicalCourseId(Map<String, dynamic> course) {
    for (final key in ['id', 'courseId', 'docId', 'code', 'courseCode']) {
      final value = course[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _retrieveCandidatesFromToolPlan({
    required String userMessage,
    required Map<String, dynamic> toolPlan,
    required List<Map<String, dynamic>> courseTools,
    required int maxCandidates,
  }) {
    final globalTerms = _stringList(toolPlan['globalSearchTerms']);
    final groups = toolPlan['candidateGroups'];
    final allTerms = <String>[
      ...globalTerms,
      ..._latestPromptFieldTerms(userMessage),
    ];
    final excludeTerms = <String>[];

    if (groups is Iterable) {
      for (final group in groups) {
        if (group is Map) {
          allTerms.addAll(_stringList(group['searchTerms']));
          excludeTerms.addAll(_stringList(group['excludeTerms']));
        }
      }
    }

    final uniqueTerms = _expandedAgentSearchTerms(
      allTerms
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty)
          .toSet()
          .toList(),
    );
    final uniqueExclude = _expandedAgentSearchTerms(
      excludeTerms
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty)
          .toSet()
          .toList(),
    );
    final promptTermKeys = _latestPromptFieldTerms(userMessage)
        .map(_normalizeSearchText)
        .where((term) => term.isNotEmpty)
        .toSet();

    final scored = <_ScoredCourse>[];
    for (final course in courseTools) {
      final text = (course['searchText'] ?? '').toString();
      var score = 0;

      if (uniqueTerms.isEmpty) {
        score = 1;
      } else {
        for (final term in uniqueTerms) {
          final normalizedTerm = _normalizeSearchText(term);
          if (normalizedTerm.isEmpty) continue;
          if (text.contains(normalizedTerm)) {
            final isPromptFieldTerm = promptTermKeys.contains(normalizedTerm);
            score += (isPromptFieldTerm ? 90 : 40) + normalizedTerm.length.clamp(0, 30);
          } else {
            final tokens = normalizedTerm.split(RegExp(r'\s+')).where((token) => token.length >= 2);
            for (final token in tokens) {
              if (text.contains(token)) score += 6;
            }
          }
        }
      }

      for (final term in uniqueExclude) {
        final normalizedTerm = _normalizeSearchText(term);
        if (normalizedTerm.isNotEmpty && text.contains(normalizedTerm)) {
          score -= 50;
        }
      }

      if (course['completedOrInProgress'] == true) {
        score -= 80;
      }

      if (score > 0) {
        scored.add(_ScoredCourse(course, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    var candidates = scored.map((item) => _candidateCourseRecord(item.course)).take(maxCandidates).toList();

    // If the AI made too narrow a tool plan, do not fail immediately.
    // Give it a broad real-course tool sample and let AI decide/clarify.
    if (candidates.length < 8) {
      final existingIds = candidates.map((course) => course['id'].toString()).toSet();
      for (final course in courseTools) {
        if (candidates.length >= maxCandidates) break;
        final id = (course['id'] ?? '').toString();
        if (id.isEmpty || existingIds.contains(id)) continue;
        if (course['completedOrInProgress'] == true) continue;
        candidates.add(_candidateCourseRecord(course));
        existingIds.add(id);
      }
    }

    return candidates;
  }

  Map<String, dynamic> _candidateCourseRecord(Map<String, dynamic> course) {
    return {
      'id': course['id'],
      'code': course['code'],
      'title': course['title'],
      'titleZh': course['titleZh'],
      'department': course['department'],
      'type': course['type'],
      'credits': course['credits'],
      'professor': course['professor'],
      'time': course['time'],
      'day': course['day'],
      'startSlot': course['startSlot'],
      'duration': course['duration'],
      'location': course['location'],
      'language': course['language'],
      'limit': course['limit'],
      'remarks': course['remarks'],
      'curriculumBucket': course['curriculumBucket'],
      'curriculumRequiredName': course['curriculumRequiredName'],
      'completedOrInProgress': course['completedOrInProgress'],
    };
  }

  Map<String, dynamic> _catalogStats(List<Map<String, dynamic>> courseTools) {
    final types = <String>{};
    final departments = <String>{};
    final examples = <String>[];
    final examplesByType = <String, List<String>>{};
    final examplesByDepartment = <String, List<String>>{};

    String labelFor(Map<String, dynamic> course) {
      final code = (course['code'] ?? course['id'] ?? '').toString().trim();
      final title = (course['title'] ?? '').toString().trim();
      final titleZh = (course['titleZh'] ?? '').toString().trim();
      final type = (course['type'] ?? '').toString().trim();
      final dept = (course['department'] ?? '').toString().trim();
      final time = (course['time'] ?? '').toString().trim();
      return [
        if (code.isNotEmpty) code,
        if (title.isNotEmpty) title,
        if (titleZh.isNotEmpty) titleZh,
        if (type.isNotEmpty) 'type=$type',
        if (dept.isNotEmpty) 'dept=$dept',
        if (time.isNotEmpty) 'time=$time',
      ].join(' | ');
    }

    for (final course in courseTools) {
      final type = (course['type'] ?? '').toString().trim();
      final department = (course['department'] ?? '').toString().trim();
      final title = (course['title'] ?? course['titleZh'] ?? '').toString().trim();

      if (type.isNotEmpty) types.add(type);
      if (department.isNotEmpty) departments.add(department);
      if (title.isNotEmpty && examples.length < 30) examples.add(labelFor(course));

      if (type.isNotEmpty) {
        final bucket = examplesByType.putIfAbsent(type, () => <String>[]);
        if (bucket.length < 8) bucket.add(labelFor(course));
      }

      if (department.isNotEmpty) {
        final bucket = examplesByDepartment.putIfAbsent(department, () => <String>[]);
        if (bucket.length < 5) bucket.add(labelFor(course));
      }
    }

    return {
      'courseCount': courseTools.length,
      'types': types.take(80).toList(),
      'departments': departments.take(80).toList(),
      'exampleTitles': examples,
      'examplesByType': examplesByType,
      'examplesByDepartment': examplesByDepartment,
    };
  }

  List<String> _readSelectedIds(Map<String, dynamic> json, Map<String, String> aliasToId) {
    final raw = json['selectedCourseIds'];
    if (raw is! Iterable) return const [];

    final selected = <String>[];
    for (final item in raw) {
      final rawId = item.toString().trim();
      if (rawId.isEmpty) continue;
      final canonical = aliasToId[rawId] ??
          aliasToId[rawId.toLowerCase()] ??
          aliasToId[_aliasKey(rawId)];
      if (canonical == null || canonical.isEmpty) continue;
      if (!selected.contains(canonical)) selected.add(canonical);
    }
    return selected;
  }

  void _readAgentNotes(Map<String, dynamic> json, Map<String, String> aliasToId) {
    _lastPlanSummary = (json['planSummary'] ?? '').toString().trim();
    final rawQuestion = json['clarifyingQuestion']?.toString().trim();
    _lastClarifyingQuestion = rawQuestion == null || rawQuestion.isEmpty ? null : rawQuestion;

    final reasons = json['courseReasons'];
    if (reasons is Map) {
      for (final entry in reasons.entries) {
        final rawId = entry.key.toString().trim();
        final id = aliasToId[rawId] ??
            aliasToId[rawId.toLowerCase()] ??
            aliasToId[_aliasKey(rawId)] ??
            rawId;
        final value = entry.value;
        if (value is Iterable) {
          _lastReasonsByCourseId[id] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .take(4)
              .toList();
        }
      }
    }
  }

  List<String> _validateAiSelection({
    required List<String> selectedIds,
    required Map<String, Map<String, dynamic>> courseById,
    required Map<String, dynamic> toolPlan,
  }) {
    final feedback = <String>[];
    final seen = <String>{};
    final seenFamilies = <String, String>{};
    final occupied = <String, String>{};

    final targetCount = _toIntNullable(toolPlan['targetCount']);
    if (targetCount != null && targetCount > 0 && selectedIds.length != targetCount) {
      feedback.add('The tool plan targetCount is $targetCount, but you selected ${selectedIds.length}. Repair the count if possible.');
    }

    var totalCredits = 0;

    for (final id in selectedIds) {
      if (!seen.add(id)) {
        feedback.add('Duplicate selected course ID: $id. Choose it only once.');
        continue;
      }

      final course = courseById[id];
      if (course == null) {
        feedback.add('Selected ID $id does not exist in availableCourses.');
        continue;
      }

      totalCredits += _toInt(course['credits']);

      final family = _courseFamilyKey(course);
      final previousFamilyCourse = seenFamilies[family];
      if (family.isNotEmpty && previousFamilyCourse != null) {
        feedback.add('Duplicate section of the same course: $id is the same course family as $previousFamilyCourse. Choose only one section.');
      } else if (family.isNotEmpty) {
        seenFamilies[family] = id;
      }

      if (course['baoBaoCompletedOrInProgress'] == true ||
          course['completedOrInProgress'] == true) {
        feedback.add('Course $id is already completed or in progress. Choose a different course if possible.');
      }

      for (final key in _meetingKeys(course)) {
        final other = occupied[key];
        if (other != null) {
          feedback.add('Schedule conflict: $id conflicts with $other at $key. Choose a non-conflicting replacement if possible.');
        } else {
          occupied[key] = id;
        }
      }
    }

    final targetCreditsMin = _toIntNullable(toolPlan['targetCreditsMin']);
    final targetCreditsMax = _toIntNullable(toolPlan['targetCreditsMax']);

    if (targetCreditsMin != null && targetCreditsMin > 0 && totalCredits < targetCreditsMin) {
      feedback.add('Credit target not reached: selected $totalCredits credits but targetCreditsMin is $targetCreditsMin. Add more real non-conflicting courses from candidateCourses until the plan reaches the minimum, or explain if impossible.');
    }

    if (targetCreditsMax != null && targetCreditsMax > 0 && totalCredits > targetCreditsMax) {
      feedback.add('Credit target exceeded: selected $totalCredits credits but targetCreditsMax is $targetCreditsMax. Replace or remove courses to stay within range if possible.');
    }

    return feedback;
  }

  List<String> _safelyKeepValidAiIds({
    required List<String> selectedIds,
    required Map<String, Map<String, dynamic>> courseById,
  }) {
    final safe = <String>[];
    final seen = <String>{};
    final seenFamilies = <String>{};
    final occupied = <String, String>{};

    for (final id in selectedIds) {
      if (!seen.add(id)) continue;
      final course = courseById[id];
      if (course == null) continue;
      if (course['baoBaoCompletedOrInProgress'] == true ||
          course['completedOrInProgress'] == true) continue;

      final family = _courseFamilyKey(course);
      if (family.isNotEmpty && seenFamilies.contains(family)) continue;

      var conflict = false;
      for (final key in _meetingKeys(course)) {
        if (occupied.containsKey(key)) {
          conflict = true;
          break;
        }
      }
      if (conflict) continue;

      for (final key in _meetingKeys(course)) {
        occupied[key] = id;
      }
      if (family.isNotEmpty) seenFamilies.add(family);
      safe.add(id);
    }

    return safe;
  }

  List<String> _meetingKeys(Map<String, dynamic> course) {
    final keys = <String>[];
    final day = _toInt(course['day']);
    final startSlot = _toInt(course['startSlot']);
    final duration = _toInt(course['duration']);

    if (day > 0 && startSlot > 0) {
      final safeDuration = duration > 0 ? duration : 1;
      for (var i = 0; i < safeDuration; i++) {
        keys.add('D$day-P${startSlot + i}');
      }
    }

    final rawTime = [
      course['slotCode'],
      course['timeSlot'],
      course['time'],
      course['classTime'],
    ].whereType<Object>().map((item) => item.toString()).join(' ');

    final dayMap = {'M': 1, 'T': 2, 'W': 3, 'R': 4, 'F': 5};
    final regex = RegExp(r'([MTWRF])\s*([0-9]+|n)', caseSensitive: false);
    for (final match in regex.allMatches(rawTime.toUpperCase())) {
      final letter = match.group(1) ?? '';
      final period = match.group(2) ?? '';
      final parsedDay = dayMap[letter];
      if (parsedDay != null && period.isNotEmpty) {
        keys.add('D$parsedDay-P$period');
      }
    }

    return keys.toSet().toList();
  }

  BaoBaoCourseIntent _fallbackIntent(String userMessage) {
    final lower = userMessage.toLowerCase().trim();
    var intent = 'new_plan';
    var searchMode = 'general_plan';

    if (lower.contains('credit')) {
      searchMode = 'credit_mix';
    } else if (lower.contains('professor') ||
        lower.contains('instructor') ||
        lower.contains('taught by')) {
      intent = 'direct_search';
      searchMode = 'instructor';
    } else if (lower.contains('course') ||
        lower.contains('class') ||
        lower.contains('課') ||
        lower.split(RegExp(r'\s+')).length <= 4) {
      intent = 'direct_search';
      searchMode = 'subject';
    }

    return BaoBaoCourseIntent(
      intent: intent,
      basePlan: 'none',
      actions: const [],
      memoryUpdate: null,
      needsClarification: false,
      clarifyingQuestion: null,
      usePreviousRecommendation: false,
      searchMode: searchMode,
      query: userMessage.trim(),
    );
  }

  Map<String, dynamic> _defaultToolPlan(String userMessage) {
    final promptTerms = _latestPromptFieldTerms(userMessage);
    final lower = userMessage.toLowerCase();
    int? minCredits;
    int? maxCredits;

    final creditMatch = RegExp(r'(\d{1,2})\s*-?\s*credit').firstMatch(lower);
    if (creditMatch != null) {
      final target = int.tryParse(creditMatch.group(1) ?? '');
      if (target != null && target > 0) {
        minCredits = target <= 2 ? target : target - 2;
        maxCredits = target + 2;
      }
    }

    return {
      'goalSummary': userMessage,
      'targetCount': null,
      'targetCreditsMin': minCredits,
      'targetCreditsMax': maxCredits,
      'candidateGroups': [
        {
          'label': 'main',
          'count': null,
          'searchTerms': promptTerms.isEmpty ? [userMessage] : promptTerms,
          'excludeTerms': [],
          'notes': 'Fallback tool plan from the latest user prompt.',
        }
      ],
      'globalSearchTerms': promptTerms.isEmpty ? [userMessage] : promptTerms,
      'importantConstraints': [],
      'needsClarification': false,
      'clarifyingQuestion': null,
    };
  }

  List<String> _latestPromptFieldTerms(String userMessage) {
    final normalized = _normalizeSearchText(userMessage);
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    final terms = <String>[];

    void addAll(List<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty && !terms.contains(trimmed)) terms.add(trimmed);
      }
    }

    final asksCs = RegExp(r'\b(cs|computer science|computing|software|programming)\b')
            .hasMatch(normalized) ||
        compact.contains('computerscience');
    if (asksCs) {
      addAll([
        'computer science',
        'computing',
        'software',
        'programming',
        'algorithm',
        'algorithms',
        'data structure',
        'database',
        'operating system',
        'computer network',
        'architecture',
        'CS',
        'EECS',
      ]);
    }

    final asksBusiness = RegExp(r'\b(business|management|finance|fintech|entrepreneurship|marketing|economics)\b')
        .hasMatch(normalized);
    if (asksBusiness) {
      addAll([
        'business',
        'management',
        'finance',
        'fintech',
        'entrepreneurship',
        'marketing',
        'economics',
        'innovation',
      ]);
    }

    final asksEe = RegExp(r'\b(ee|electrical engineering|electronics|circuit|semiconductor|signal|hardware)\b')
        .hasMatch(normalized);
    if (asksEe && !asksCs) {
      addAll([
        'electrical engineering',
        'electronics',
        'circuit',
        'signal',
        'semiconductor',
        'hardware',
        'EE',
        'EECS',
      ]);
    }

    if (compact == 'pe' || normalized.contains('physical education') ||
        normalized.contains('sport') || normalized.contains('sports') ||
        normalized.contains('體育') || normalized.contains('体育')) {
      addAll(['PE', 'physical education', 'sports', '體育', '体育']);
    }

    return terms;
  }

  List<String> _expandedAgentSearchTerms(List<String> terms) {
    final output = <String>[];

    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (!output.contains(trimmed)) output.add(trimmed);
    }

    for (final term in terms) {
      add(term);
      final normalized = _normalizeSearchText(term);
      final compact = normalized.replaceAll(RegExp(r'\s+'), '');

      // Small, general tool vocabulary only. These are not course IDs or
      // recommendations; they help the real-course retrieval tool understand
      // common category names before the AI chooses final cards.
      if (normalized.contains('computer science') ||
          compact == 'cs' ||
          normalized.contains('computing') ||
          normalized.contains('software') ||
          normalized.contains('programming')) {
        add('computer science');
        add('computing');
        add('software');
        add('programming');
        add('algorithm');
        add('algorithms');
        add('data structure');
        add('database');
        add('operating system');
        add('computer network');
        add('CS');
        add('EECS');
      }

      if (normalized.contains('business') ||
          normalized.contains('management') ||
          normalized.contains('finance') ||
          normalized.contains('fintech') ||
          normalized.contains('entrepreneurship') ||
          normalized.contains('marketing') ||
          normalized.contains('economics')) {
        add('business');
        add('management');
        add('finance');
        add('fintech');
        add('entrepreneurship');
        add('marketing');
        add('economics');
        add('innovation');
      }

      if (compact == 'pe' || normalized.contains('physical education')) {
        add('physical education');
        add('sport');
        add('sports');
        add('體育');
        add('体育');
      }

      if (compact == 'ge' || normalized.contains('general education')) {
        add('general education');
        add('core general');
        add('通識');
        add('通识');
      }

      if (normalized.contains('language') ||
          normalized.contains('mandarin') ||
          normalized.contains('chinese course') ||
          normalized.contains('japanese') ||
          normalized.contains('korean') ||
          normalized.contains('french') ||
          normalized.contains('german')) {
        add('language');
        add('foreign language');
        add('mandarin');
        add('chinese');
        add('japanese');
        add('華語');
        add('中文');
        add('日文');
        add('語言');
        add('语言');
      }

      if (normalized.contains('chill') ||
          normalized.contains('easy') ||
          normalized.contains('light workload') ||
          normalized.contains('low workload')) {
        add('general education');
        add('elective');
        add('通識');
        add('management');
        add('innovation');
        add('society');
      }
    }

    return output;
  }

  List<String> _fillCreditGapWithValidCourses({
    required List<String> selectedIds,
    required List<Map<String, dynamic>> preferredCandidates,
    required Map<String, Map<String, dynamic>> courseById,
    required Map<String, dynamic> toolPlan,
  }) {
    final targetCount = _toIntNullable(toolPlan['targetCount']);
    if (targetCount != null && targetCount > 0) {
      return selectedIds;
    }

    final targetMin = _toIntNullable(toolPlan['targetCreditsMin']);
    final targetMax = _toIntNullable(toolPlan['targetCreditsMax']);
    if (targetMin == null || targetMin <= 0) {
      return selectedIds;
    }

    final filled = <String>[];
    final seen = <String>{};
    final seenFamilies = <String>{};
    final occupied = <String, String>{};
    var totalCredits = 0;

    bool canUseCourse(String id, Map<String, dynamic> course) {
      if (id.isEmpty || seen.contains(id)) return false;
      if (course['baoBaoCompletedOrInProgress'] == true ||
          course['completedOrInProgress'] == true) {
        return false;
      }
      final family = _courseFamilyKey(course);
      if (family.isNotEmpty && seenFamilies.contains(family)) {
        return false;
      }
      final credits = _toInt(course['credits']);
      if (credits <= 0) return false;
      if (targetMax != null && targetMax > 0 && totalCredits + credits > targetMax) {
        return false;
      }
      for (final key in _meetingKeys(course)) {
        if (occupied.containsKey(key)) return false;
      }
      return true;
    }

    void addCourse(String id, Map<String, dynamic> course) {
      filled.add(id);
      seen.add(id);
      final family = _courseFamilyKey(course);
      if (family.isNotEmpty) seenFamilies.add(family);
      totalCredits += _toInt(course['credits']);
      for (final key in _meetingKeys(course)) {
        occupied[key] = id;
      }
    }

    for (final id in selectedIds) {
      final course = courseById[id];
      if (course == null) continue;
      if (!canUseCourse(id, course)) continue;
      addCourse(id, course);
    }

    if (totalCredits >= targetMin) return filled;

    final candidateIds = <String>[];
    for (final candidate in preferredCandidates) {
      final id = (candidate['id'] ?? candidate['code'] ?? '').toString().trim();
      if (id.isEmpty || candidateIds.contains(id)) continue;
      candidateIds.add(id);
    }

    for (final id in candidateIds) {
      if (totalCredits >= targetMin) break;
      final course = courseById[id];
      if (course == null) continue;
      if (!canUseCourse(id, course)) continue;
      addCourse(id, course);
    }

    return filled;
  }

  List<String> _stringList(dynamic value) {
    if (value == null) return const [];
    if (value is String) return value.trim().isEmpty ? const [] : [value.trim()];
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    return [value.toString().trim()].where((item) => item.isNotEmpty).toList();
  }

  String _searchableCourseText(Map<String, dynamic> course) {
    return _normalizeSearchText([
      course['id'],
      course['courseId'],
      course['docId'],
      course['code'],
      course['courseCode'],
      course['title'],
      course['titleEn'],
      course['titleZh'],
      course['chineseTitle'],
      course['name'],
      course['courseName'],
      course['department'],
      course['dept'],
      course['departmentCode'],
      course['type'],
      course['courseType'],
      course['category'],
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
      course['professor'],
      course['teacher'],
      course['instructor'],
      course['slotCode'],
      course['timeSlot'],
      course['time'],
      course['classTime'],
      course['place'],
      course['location'],
      course['classroom'],
      course['room'],
      course['language'],
      course['instructionLanguage'],
      course['languageOfInstruction'],
      course['teachingLanguage'],
      course['courseLanguage'],
      course['remarks'],
      course['note'],
      course['description'],
      course['summary'],
    ].whereType<Object>().join(' '));
  }

  String _courseFamilyKey(Map<String, dynamic> course) {
    final titleText = [
      course['title'],
      course['titleEn'],
      course['titleZh'],
      course['name'],
      course['courseName'],
    ]
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .join(' ');

    // Prefer title identity so different sections of the same course collapse.
    // Only fall back to code/id when no title exists.
    final raw = titleText.trim().isNotEmpty
        ? titleText
        : [course['code'], course['id']]
            .whereType<Object>()
            .map((item) => item.toString())
            .join(' ');

    var key = _normalizeSearchText(raw).replaceAll(RegExp(r'\s+'), '');
    if (key.length < 4) return '';

    key = key
        .replaceAll('laboratory', 'lab')
        .replaceAll('labsection', 'lab')
        .replaceAll('實驗室', '實驗')
        .replaceAll('實驗課', '實驗')
        .replaceAll('體育課', '體育');

    key = key.replaceFirst(RegExp(r'^\d{5}'), '');
    key = key.replaceAll(RegExp(r'(section|class|班別|組別)[a-z0-9]+$'), '');
    return key;
  }

  String _removeSemesterPrefix(String value) {
    return value.replaceFirst(RegExp(r'^\d{5}'), '');
  }

  String _aliasKey(String value) {
    return _normalizeSearchText(value).replaceAll(RegExp(r'\s+'), '');
  }

  String _normalizeSearchText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _extractJsonObject(String text) {
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('No JSON object found');
    }
    return cleaned.substring(start, end + 1);
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        final dynamic timestamp = value;
        return timestamp.toDate().toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), _jsonSafe(item)));
    }
    return value.toString();
  }
}

class _ScoredCourse {
  final Map<String, dynamic> course;
  final int score;

  const _ScoredCourse(this.course, this.score);
}
