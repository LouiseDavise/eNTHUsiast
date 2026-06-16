import '../api/bao_bao_ai_api.dart';

class BaoBaoCourseAgent {
  final BaoBaoAiApi aiApi;

  BaoBaoCourseAgent({
    required this.aiApi,
  });

  Future<BaoBaoPlanResult> planCourse({
    required String userMessage,
    required List<Map<String, dynamic>> courseCatalog,
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? graduationData,
    Map<String, dynamic>? userPreferences,
    BaoBaoCourseIntent? intent,
  }) async {
    final trace = <BaoBaoAgentStep>[];

    trace.add(const BaoBaoAgentStep(
      name: 'agentMode',
      status: 'done',
      message: 'AI-agent mode: Dart provides course tools/data + validation; AI plans, scans, and chooses the courses.',
    ));

    final toolCourses = _prepareCourseToolData(
      courseCatalog: courseCatalog,
      graduationData: graduationData,
    );

    trace.add(BaoBaoAgentStep(
      name: 'loadCourseTools',
      status: 'done',
      message: 'Provided ${toolCourses.length} real course cards to Bao-Bao.',
    ));

    final toolProfile = _mergeToolContext(
      userPreferences: userPreferences,
      graduationData: graduationData,
      curriculum: curriculum,
    );

    trace.add(const BaoBaoAgentStep(
      name: 'loadUserTools',
      status: 'done',
      message: 'Provided profile, curriculum, memory, and completed-course hints as tool data.',
    ));

    final recommendedIds = await aiApi.askBaoBaoRecommendedCourseIds(
      userMessage: userMessage,
      courseCatalog: toolCourses,
      curriculum: curriculum,
      userPreferences: toolProfile,
      intent: intent,
    );

    final courseById = <String, Map<String, dynamic>>{};
    for (final course in toolCourses) {
      for (final key in _courseAliasKeys(course)) {
        courseById[key] = course;
      }
    }

    final recommendedCourses = <Map<String, dynamic>>[];
    final displayedFamilies = <String>{};
    final occupied = <String, String>{};
    for (final rawId in recommendedIds) {
      final lookupKeys = _idLookupKeys(rawId);
      Map<String, dynamic>? original;
      for (final key in lookupKeys) {
        original = courseById[key];
        if (original != null) break;
      }
      if (original == null) continue;

      // Second hard guard AFTER AI returns IDs. Even if the AI selects it,
      // do not display courses already completed/in-progress, duplicate
      // sections of the same course, or time-conflicting cards.
      if (original['baoBaoCompletedOrInProgress'] == true ||
          original['completedOrInProgress'] == true) {
        continue;
      }

      final family = _courseFamilyKey(_courseLabel(original));
      if (family.isNotEmpty && displayedFamilies.contains(family)) {
        continue;
      }

      var hasConflict = false;
      for (final key in _meetingKeys(original)) {
        if (occupied.containsKey(key)) {
          hasConflict = true;
          break;
        }
      }
      if (hasConflict) continue;

      if (family.isNotEmpty) displayedFamilies.add(family);
      for (final key in _meetingKeys(original)) {
        occupied[key] = _courseLabel(original);
      }

      final copied = Map<String, dynamic>.from(original);
      final canonicalId = (copied['id'] ?? rawId).toString();
      final reasons = aiApi.lastReasonsByCourseId[canonicalId] ??
          aiApi.lastReasonsByCourseId[rawId] ??
          aiApi.lastReasonsByCourseId[(copied['code'] ?? '').toString()];
      copied['baoBaoWhy'] = (reasons == null || reasons.isEmpty)
          ? ['Bao-Bao AI selected this from the real course tools.']
          : reasons;
      copied['baoBaoConfidenceLabel'] = 'AI-selected';
      copied['baoBaoConfidenceScore'] = 0;
      recommendedCourses.add(copied);
    }

    trace.add(BaoBaoAgentStep(
      name: 'aiChooseCourses',
      status: recommendedCourses.isEmpty ? 'warning' : 'done',
      message: recommendedCourses.isEmpty
          ? (aiApi.lastClarifyingQuestion ?? 'Bao-Bao could not select matching real course cards.')
          : 'Bao-Bao selected ${recommendedCourses.length} real course cards.',
    ));

    final validation = _validatePlan(recommendedCourses);

    trace.add(BaoBaoAgentStep(
      name: 'toolValidatePlan',
      status: validation.hasCriticalIssue ? 'warning' : 'done',
      message: validation.summary,
    ));

    final explanation = _explainPlan(
      userMessage: userMessage,
      plannedCourses: recommendedCourses,
      validation: validation,
    );

    return BaoBaoPlanResult(
      recommendedCourseIds: recommendedIds,
      recommendedCourses: recommendedCourses,
      validation: validation,
      explanation: explanation,
      trace: trace,
    );
  }

  List<Map<String, dynamic>> _prepareCourseToolData({
    required List<Map<String, dynamic>> courseCatalog,
    required Map<String, dynamic>? graduationData,
  }) {
    final completedHints = _completedHints(graduationData);
    final seenIds = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final raw in courseCatalog) {
      if (raw.isEmpty) continue;
      final copied = Map<String, dynamic>.from(raw);
      final id = _readFirst(copied, const ['id', 'courseId', 'docId', 'code', 'courseCode']);
      final code = _readFirst(copied, const ['code', 'courseCode', 'id']);
      if (id.isEmpty || seenIds.contains(id)) continue;
      seenIds.add(id);
      copied['id'] = id;
      if (code.isNotEmpty) copied['code'] = code;
      copied['baoBaoCompletedOrInProgress'] = _matchesCompletedHints(copied, completedHints);
      result.add(copied);
    }

    return result;
  }

  String _readFirst(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  Map<String, dynamic> _mergeToolContext({
    required Map<String, dynamic>? userPreferences,
    required Map<String, dynamic>? graduationData,
    required Map<String, dynamic>? curriculum,
  }) {
    return {
      'userPreferences': userPreferences ?? {},
      'graduationData': graduationData ?? {},
      'hasCurriculum': curriculum != null && curriculum.isNotEmpty,
      'completedOrInProgressHints': _completedHints(graduationData).take(120).toList(),
      'agentInstruction': 'Latest prompt is priority 1. Profile/curriculum/memory are priority 2. AI chooses; Dart supplies tools and validates real IDs/conflicts.',
    };
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
      keys.addAll(_idLookupKeys(value));
    }
    return keys.where((key) => key.trim().isNotEmpty).toList();
  }

  List<String> _idLookupKeys(String value) {
    final keys = <String>{};
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    keys.add(trimmed);
    keys.add(trimmed.toLowerCase());

    final normalized = _normalizeCourseMatchKey(trimmed);
    if (normalized.isNotEmpty) keys.add(normalized);

    final noSemester = _removeSemesterPrefix(normalized);
    if (noSemester.length >= 5) keys.add(noSemester);

    final match = RegExp(r'^([a-z]{2,6})(\d{3})\d*$').firstMatch(noSemester);
    if (match != null) {
      keys.add('${match.group(1)}${match.group(2)}');
    }

    return keys.toList();
  }

  BaoBaoPlanValidation _validatePlan(List<Map<String, dynamic>> plannedCourses) {
    final warnings = <String>[];
    final validIds = <String>[];
    final bucketCounts = <String, int>{};
    final occupied = <String, String>{};
    var totalCredits = 0;
    var curriculumMatches = 0;

    for (final course in plannedCourses) {
      final id = (course['id'] ?? course['code'] ?? '').toString();
      if (id.isNotEmpty) validIds.add(id);

      totalCredits += _toInt(course['credits']);

      final bucket = _bucketName(course);
      bucketCounts[bucket] = (bucketCounts[bucket] ?? 0) + 1;
      if ((course['curriculumMatchedBy'] ?? '').toString().trim().isNotEmpty) {
        curriculumMatches++;
      }

      if (course['baoBaoCompletedOrInProgress'] == true) {
        warnings.add('${_courseLabel(course)} is already completed or in progress.');
      }

      for (final key in _meetingKeys(course)) {
        final other = occupied[key];
        if (other != null) {
          warnings.add('${_courseLabel(course)} conflicts with $other at $key.');
        } else {
          occupied[key] = _courseLabel(course);
        }
      }
    }

    final summary = warnings.isEmpty
        ? 'Tool validation passed: ${plannedCourses.length} course(s), $totalCredits credit(s), no detected time conflict.'
        : 'Tool validation found ${warnings.length} warning(s).';

    return BaoBaoPlanValidation(
      totalCredits: totalCredits,
      validCourseIds: validIds,
      warnings: warnings,
      curriculumMatches: curriculumMatches,
      bucketCounts: bucketCounts,
      hasCriticalIssue: warnings.isNotEmpty,
      summary: summary,
    );
  }

  String _explainPlan({
    required String userMessage,
    required List<Map<String, dynamic>> plannedCourses,
    required BaoBaoPlanValidation validation,
  }) {
    if (plannedCourses.isEmpty) {
      return aiApi.lastClarifyingQuestion ??
          'Bao-Bao could not find matching real course cards for: "$userMessage".';
    }

    final aiSummary = aiApi.lastPlanSummary.trim();
    final courseLines = plannedCourses.map((course) {
      final title = (course['title'] ?? course['titleEn'] ?? course['code'] ?? course['id']).toString();
      final reasons = course['baoBaoWhy'];
      final reasonText = reasons is Iterable && reasons.isNotEmpty
          ? reasons.first.toString()
          : 'AI selected this from the course tools.';
      return '- $title: $reasonText';
    }).join('\n');

    return [
      if (aiSummary.isNotEmpty) aiSummary,
      courseLines,
      validation.summary,
    ].where((part) => part.trim().isNotEmpty).join('\n');
  }

  Set<String> _completedHints(Map<String, dynamic>? graduationData) {
    final hints = <String>{};

    void addHint(dynamic raw) {
      if (raw == null) return;
      final text = raw.toString().trim();
      if (text.length < 2) return;

      final normalized = _normalizeCourseMatchKey(text);
      if (normalized.length >= 2) hints.add(normalized);

      final noSemester = _removeSemesterPrefix(normalized);
      if (noSemester.length >= 2) hints.add(noSemester);

      // Course-family key catches same course with different section/code wording.
      // Example: "General Physics Lab (II)" vs "General Physics Laboratory (II)".
      final family = _courseFamilyKey(text);
      if (family.length >= 4) hints.add(family);
    }

    bool statusMeansDoneOrCurrent(dynamic rawStatus) {
      final status = rawStatus?.toString().toLowerCase().trim() ?? '';
      if (status.isEmpty) return false;

      return status == 'passed' ||
          status == 'pass' ||
          status == 'completed' ||
          status == 'complete' ||
          status == 'in progress' ||
          status == 'in-progress' ||
          status == 'current' ||
          status == 'taking' ||
          status == 'enrolled' ||
          status.contains('in progress') ||
          status.contains('in-progress') ||
          status.contains('passed') ||
          status.contains('completed') ||
          status.contains('taking') ||
          status.contains('enrolled') ||
          status.contains('修過') ||
          status.contains('已修') ||
          status.contains('通過') ||
          status.contains('抵免') ||
          status.contains('正在修') ||
          status.contains('修讀中') ||
          status.contains('修课中');
    }

    void addCourseKeysFromMap(Map value) {
      for (final key in [
        'id',
        'code',
        'courseCode',
        'courseId',
        'docId',
        'title',
        'name',
        'courseName',
        'titleEn',
        'titleZh',
        'englishName',
        'chineseName',
      ]) {
        addHint(value[key]);
      }
    }

    void collect(dynamic value, {bool inheritedDoneOrCurrent = false}) {
      if (value == null) return;

      if (value is Iterable) {
        for (final item in value) {
          collect(item, inheritedDoneOrCurrent: inheritedDoneOrCurrent);
        }
        return;
      }

      if (value is Map) {
        final status = value['status'] ??
            value['completionStatus'] ??
            value['state'] ??
            value['result'] ??
            value['progressStatus'];

        final thisRecordIsDoneOrCurrent = inheritedDoneOrCurrent ||
            statusMeansDoneOrCurrent(status);

        // Only add fields from a map when this map, or a parent wrapper map,
        // clearly says the record is passed/completed/currently taking.
        // This handles structures like:
        // {status: IN PROGRESS, course: {code: ..., title: ...}}
        // without treating every string inside graduationData as completed.
        if (thisRecordIsDoneOrCurrent) {
          addCourseKeysFromMap(value);
        }

        for (final item in value.values) {
          if (item is Iterable || item is Map) {
            collect(item, inheritedDoneOrCurrent: thisRecordIsDoneOrCurrent);
          }
        }
      }
    }

    collect(graduationData);
    return hints;
  }

  bool _matchesCompletedHints(Map<String, dynamic> course, Set<String> hints) {
    if (hints.isEmpty) return false;

    final courseKeys = <String>{};

    void addCourseKey(dynamic raw) {
      if (raw == null) return;
      final text = raw.toString().trim();
      if (text.length < 2) return;
      final normalized = _normalizeCourseMatchKey(text);
      if (normalized.length >= 2) courseKeys.add(normalized);
      final noSemester = _removeSemesterPrefix(normalized);
      if (noSemester.length >= 2) courseKeys.add(noSemester);

      final family = _courseFamilyKey(text);
      if (family.length >= 4) courseKeys.add(family);
    }

    for (final key in [
      'id',
      'code',
      'courseCode',
      'courseId',
      'docId',
      'title',
      'titleEn',
      'titleZh',
      'name',
      'courseName',
    ]) {
      addCourseKey(course[key]);
    }

    for (final key in courseKeys) {
      if (hints.contains(key)) return true;
    }

    // Code suffix match only for long alphanumeric course codes, e.g.
    // 11420EECS402000 vs EECS402000. Avoid loose matching on short titles.
    final codeLikeKeys = courseKeys.where((key) {
      return RegExp(r'[a-z]{2,}\d{3,}').hasMatch(key) ||
          RegExp(r'\d{5}[a-z]{2,}\d{3,}').hasMatch(key);
    }).toList();

    for (final courseKey in codeLikeKeys) {
      for (final hint in hints) {
        if (hint.length < 6) continue;
        if (courseKey.endsWith(hint) || hint.endsWith(courseKey)) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeCourseMatchKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9一-鿿]+'), '')
        .trim();
  }

  String _removeSemesterPrefix(String value) {
    return value.replaceFirst(RegExp(r'^\d{5}'), '');
  }

  String _courseFamilyKey(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.length < 2) return '';

    var key = _normalizeCourseMatchKey(text);

    // Normalize common catalog/transcript wording differences.
    key = key
        .replaceAll('laboratory', 'lab')
        .replaceAll('labsection', 'lab')
        .replaceAll('實驗室', '實驗')
        .replaceAll('實驗課', '實驗')
        .replaceAll('體育課', '體育');

    // Remove pure section/instructor fragments only after course identity text.
    key = key.replaceAll(RegExp(r'(section|class|班別|組別)[a-z0-9]+$'), '');

    return key;
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

  String _bucketName(Map<String, dynamic> course) {
    final values = [course['curriculumBucket'], course['type'], course['category']];
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text.toUpperCase();
    }
    return 'UNKNOWN';
  }

  String _courseLabel(Map<String, dynamic> course) {
    return (course['title'] ?? course['titleEn'] ?? course['code'] ?? course['id'] ?? 'course').toString();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BaoBaoPlanResult {
  final List<String> recommendedCourseIds;
  final List<Map<String, dynamic>> recommendedCourses;
  final BaoBaoPlanValidation validation;
  final String explanation;
  final List<BaoBaoAgentStep> trace;

  const BaoBaoPlanResult({
    required this.recommendedCourseIds,
    required this.recommendedCourses,
    required this.validation,
    required this.explanation,
    required this.trace,
  });
}

class BaoBaoPlanValidation {
  final int totalCredits;
  final List<String> validCourseIds;
  final List<String> warnings;
  final int curriculumMatches;
  final Map<String, int> bucketCounts;
  final bool hasCriticalIssue;
  final String summary;

  const BaoBaoPlanValidation({
    required this.totalCredits,
    required this.validCourseIds,
    required this.warnings,
    required this.curriculumMatches,
    required this.bucketCounts,
    required this.hasCriticalIssue,
    required this.summary,
  });
}

class BaoBaoAgentStep {
  final String name;
  final String status;
  final String message;

  const BaoBaoAgentStep({
    required this.name,
    required this.status,
    required this.message,
  });
}
