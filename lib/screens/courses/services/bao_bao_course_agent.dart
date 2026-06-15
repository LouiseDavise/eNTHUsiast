import '../api/bao_bao_ai_api.dart';

class _PreferenceFitResult {
  final int score;
  final List<String> reasons;

  const _PreferenceFitResult({
    required this.score,
    required this.reasons,
  });
}

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

    final hasCurriculum = _hasUsableCurriculum(curriculum);

    trace.add(
      BaoBaoAgentStep(
        name: 'getCurriculum',
        status: hasCurriculum ? 'done' : 'skipped',
        message: hasCurriculum
            ? 'Curriculum found. Bao-Bao will map courses into curriculum buckets.'
            : 'No curriculum uploaded yet. Bao-Bao will keep CORE courses related to the user department/career path, and use GE preferences for GE/elective options.',
      ),
    );

    final rawAvailableCourses = _getAvailableCourses(courseCatalog);

    trace.add(
      BaoBaoAgentStep(
        name: 'getAvailableCourses',
        status: 'done',
        message: 'Found ${rawAvailableCourses.length} available courses.',
      ),
    );

    final completedCourses = _getCompletedCourses(graduationData);

    print('Bao-Bao completed/in-progress keys count: ${completedCourses.length}');
    print('Bao-Bao completed/in-progress keys: ${completedCourses.take(80).toList()}');

    trace.add(
      BaoBaoAgentStep(
        name: 'getCompletedCourses',
        status: completedCourses.isEmpty ? 'skipped' : 'done',
        message: completedCourses.isEmpty
            ? 'No completed or in-progress course data detected.'
            : 'Found ${completedCourses.length} completed/in-progress course hints.',
      ),
    );

    final baoBaoMemory = _memoryMap(userPreferences);
    final memorySummary = _memorySummary(baoBaoMemory);

    trace.add(
      BaoBaoAgentStep(
        name: 'loadBaoBaoMemory',
        status: baoBaoMemory.isEmpty ? 'skipped' : 'done',
        message: baoBaoMemory.isEmpty
            ? 'No saved Bao-Bao preference memory yet.'
            : 'Loaded Bao-Bao memory: $memorySummary.',
      ),
    );

    final bucketedCourses = _attachCurriculumBuckets(
      rawAvailableCourses,
      curriculum,
    );

    final studentYear = _inferStudentYear(
      curriculum: curriculum,
      graduationData: graduationData,
      courseCatalog: rawAvailableCourses,
    );

    print('Bao-Bao inferred student year: $studentYear');

    final yearAwareCourses = _attachYearFit(
      courses: bucketedCourses,
      studentYear: studentYear,
    );

    final preferenceAwareCourses = _attachUserPreferenceInsights(
      courses: yearAwareCourses,
      userPreferences: userPreferences,
    );

    final memoryAwareCourses = _attachBaoBaoMemoryInsights(
      courses: preferenceAwareCourses,
      userPreferences: userPreferences,
    );

    final isDirectLookup = _isFreshDirectLookup(intent);
    final isOpenEndedGoalPlan = _isOpenEndedGoalPlan(intent);
    print('Bao-Bao direct lookup mode: $isDirectLookup');
    print('Bao-Bao open-ended goal planning mode: $isOpenEndedGoalPlan');

    final shouldBypassStrictPolicy = isDirectLookup || isOpenEndedGoalPlan;

    final policyAwareCourses = shouldBypassStrictPolicy
        ? memoryAwareCourses
        : _applyPreferenceAwareCoreAndGeRules(
            courses: memoryAwareCourses,
            hasCurriculum: hasCurriculum,
            curriculum: curriculum,
            graduationData: graduationData,
            userPreferences: userPreferences,
          );

    final memoryFilteredCourses = isDirectLookup
        ? policyAwareCourses
        : _filterByBaoBaoMemory(
            courses: policyAwareCourses,
            userPreferences: userPreferences,
          );

    final languageAwareCourses = shouldBypassStrictPolicy
        ? memoryFilteredCourses
        : _filterByUserLanguagePreference(
            courses: memoryFilteredCourses,
            userPreferences: userPreferences,
          );

   final bucketCountsBeforeFilter = _bucketCounts(languageAwareCourses);

    trace.add(
      BaoBaoAgentStep(
        name: 'mapCoursesToCurriculumBuckets',
        status: hasCurriculum ? 'done' : 'skipped',
        message: hasCurriculum
            ? 'Mapped courses to curriculum buckets: ${_formatBucketCounts(bucketCountsBeforeFilter)}.'
            : 'Skipped exact bucket mapping because no curriculum was found. Using career/department-aware CORE and GE/elective preference rules.',
      ),
    );

    final availableCourses = _dedupeSameCourse(
      languageAwareCourses.where((course) {
        return !_courseMatchesBlockedList(course, completedCourses) &&
            !_isTooAdvancedForStudentYear(course, studentYear);
      }).toList(),
    );

    trace.add(
      BaoBaoAgentStep(
        name: 'filterUnavailableCourses',
        status: 'done',
        message:
            'Removed completed/in-progress courses and duplicate course sections. ${availableCourses.length} courses remain.',
      ),
    );

    trace.add(
      BaoBaoAgentStep(
        name: 'planCourse',
        status: 'running',
        message: hasCurriculum
            ? 'Generating candidate plan from the user prompt first, then curriculum and preferences...'
            : 'Generating candidate plan from the user prompt first, then profile, career, and preferences...',
      ),
    );

    final recommendedIds = await aiApi.askBaoBaoRecommendedCourseIds(
      userMessage: userMessage,
      courseCatalog: availableCourses,
      curriculum: curriculum,
      userPreferences: userPreferences,
      intent: intent,
    );

    final recommendedCourses = availableCourses.where((course) {
      final id = course['id']?.toString() ?? '';
      final code = course['code']?.toString() ?? '';

      return recommendedIds.contains(id) || recommendedIds.contains(code);
    }).map((course) {
      final copied = Map<String, dynamic>.from(course);
      final reasons = _buildBaoBaoCourseReasons(
        course: copied,
        hasCurriculum: hasCurriculum,
        userPreferences: userPreferences,
      );

      copied['baoBaoWhy'] = reasons;
      copied['baoBaoConfidenceLabel'] = _baoBaoConfidenceLabel(copied);
      copied['baoBaoConfidenceScore'] = _baoBaoConfidenceScore(copied);

      return copied;
    }).toList();

    trace.add(
      BaoBaoAgentStep(
        name: 'planCourse',
        status: recommendedCourses.isEmpty ? 'warning' : 'done',
        message: recommendedCourses.isEmpty
            ? 'Bao-Bao could not create a matching plan.'
            : 'Bao-Bao created a candidate plan with ${recommendedCourses.length} courses.',
      ),
    );

    final validation = _validatePlan(
      plannedCourses: recommendedCourses,
      completedCourses: completedCourses,
      curriculum: curriculum,
    );

    trace.add(
      BaoBaoAgentStep(
        name: 'validatePlan',
        status: validation.hasCriticalIssue ? 'warning' : 'done',
        message: validation.summary,
      ),
    );

    final explanation = _explainPlan(
      userMessage: userMessage,
      plannedCourses: recommendedCourses,
      curriculum: curriculum,
      validation: validation,
      completedCourses: completedCourses,
    );

    trace.add(
      const BaoBaoAgentStep(
        name: 'explainPlan',
        status: 'done',
        message: 'Explanation generated.',
      ),
    );

    return BaoBaoPlanResult(
      recommendedCourseIds: recommendedIds,
      recommendedCourses: recommendedCourses,
      validation: validation,
      explanation: explanation,
      trace: trace,
    );
  }


  bool _isFreshDirectLookup(BaoBaoCourseIntent? intent) {
    if (intent == null) {
      return false;
    }

    // For a follow-up like "same as before but add calculus" or
    // "add professor X's class to my plan", Bao-Bao should search the
    // real catalog for the NEW requested course using direct lookup rules.
    // The dialog layer will merge the new IDs with the previous/current plan.
    if (!intent.isDirectSearch && !intent.isModifyPreviousPlan) {
      return false;
    }

    final mode = intent.searchMode.toLowerCase().trim();

    return mode == 'instructor' ||
        mode == 'subject' ||
        mode == 'time' ||
        mode == 'course_type' ||
        mode == 'credit_mix';
  }


  bool _isOpenEndedGoalPlan(BaoBaoCourseIntent? intent) {
    if (intent == null) {
      return false;
    }

    return intent.intent == 'new_plan' &&
        intent.searchMode.toLowerCase().trim() == 'general_plan';
  }

  Map<String, dynamic> _memoryMap(Map<String, dynamic>? rawPreferences) {
    final prefs = _preferenceMap(rawPreferences);
    final rawMemory = prefs['baoBaoMemory'];

    if (rawMemory is Map) {
      return Map<String, dynamic>.from(rawMemory);
    }

    return {};
  }

  String _memorySummary(Map<String, dynamic> memory) {
    final liked = _stringListFromAny(memory['likedCourseIds']).length;
    final disliked = _stringListFromAny(memory['dislikedCourseIds']).length;
    final preferred = _stringListFromAny(memory['preferredKeywords']).take(3).join(', ');
    final avoid = _stringListFromAny(memory['avoidKeywords']).take(3).join(', ');

    final parts = <String>[];
    if (liked > 0) parts.add('$liked liked courses');
    if (disliked > 0) parts.add('$disliked avoided courses');
    if (preferred.isNotEmpty) parts.add('prefers $preferred');
    if (avoid.isNotEmpty) parts.add('avoids $avoid');

    return parts.isEmpty ? 'empty memory' : parts.join('; ');
  }

  List<Map<String, dynamic>> _attachBaoBaoMemoryInsights({
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic>? userPreferences,
  }) {
    final memory = _memoryMap(userPreferences);
    if (memory.isEmpty) return courses;

    final likedIds = _stringListFromAny(memory['likedCourseIds']).toSet();
    final likedCodes = _stringListFromAny(memory['likedCourseCodes']).toSet();
    final preferredKeywords = _stringListFromAny(memory['preferredKeywords'])
        .where((item) => !_isGenericPlanningMemoryKeyword(item))
        .toList();

    return courses.map((course) {
      final copied = Map<String, dynamic>.from(course);
      final reasons = List<String>.from(
        (copied['preferenceReasons'] is Iterable)
            ? copied['preferenceReasons'] as Iterable
            : const [],
      );
      var score = _toInt(copied['preferenceFitScore']);

      final id = copied['id']?.toString() ?? '';
      final code = copied['code']?.toString() ?? '';
      final courseText = _normalizeText(_courseMemoryText(copied));

      if (likedIds.contains(id) || likedCodes.contains(code)) {
        score += 500;
        reasons.add('Bao-Bao memory: you accepted this course before');
      }

      for (final keyword in preferredKeywords) {
        final normalizedKeyword = _normalizeText(keyword);
        if (normalizedKeyword.isNotEmpty && courseText.contains(normalizedKeyword)) {
          score += 260;
          reasons.add('Bao-Bao memory: matches your saved preference “$keyword”');
          break;
        }
      }

      copied['preferenceFitScore'] = score;
      copied['preferenceReasons'] = reasons.toSet().toList();

      return copied;
    }).toList();
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

  List<Map<String, dynamic>> _filterByBaoBaoMemory({
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic>? userPreferences,
  }) {
    final memory = _memoryMap(userPreferences);
    if (memory.isEmpty) return courses;

    final dislikedIds = _stringListFromAny(memory['dislikedCourseIds']).toSet();
    final dislikedCodes = _stringListFromAny(memory['dislikedCourseCodes']).toSet();
    final avoidKeywords = _stringListFromAny(memory['avoidKeywords']);

    return courses.where((course) {
      final id = course['id']?.toString() ?? '';
      final code = course['code']?.toString() ?? '';

      if (dislikedIds.contains(id) || dislikedCodes.contains(code)) {
        return false;
      }

      final courseText = _normalizeText(_courseMemoryText(course));
      for (final keyword in avoidKeywords) {
        final normalizedKeyword = _normalizeText(keyword);
        if (normalizedKeyword.isNotEmpty && courseText.contains(normalizedKeyword)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _courseMemoryText(Map<String, dynamic> course) {
    return [
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['professor'],
      course['department'],
      course['type'],
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
    ].whereType<Object>().join(' ');
  }

  List<String> _buildBaoBaoCourseReasons({
    required Map<String, dynamic> course,
    required bool hasCurriculum,
    required Map<String, dynamic>? userPreferences,
  }) {
    final reasons = <String>[];
    final prefs = _preferenceMap(userPreferences);
    final type = (course['type'] ?? '').toString().toUpperCase();
    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();
    final matchedBy = (course['curriculumMatchedBy'] ?? '').toString().toLowerCase();
    final languagePreference = _normalizedInstructionLanguagePreference(
      (prefs['languagePreference'] ?? '').toString(),
    );

    void addReason(String reason) {
      final trimmed = reason.trim();
      if (trimmed.isEmpty) return;
      if (!reasons.contains(trimmed)) reasons.add(trimmed);
    }

    if (hasCurriculum && _hasExactCurriculumMatch(course)) {
      addReason('Matches your uploaded curriculum requirement');
    } else if (hasCurriculum && bucket.isNotEmpty && bucket != 'UNKNOWN') {
      addReason('Fits curriculum bucket: ${_friendlyBucketName(bucket)}');
    }

    if (!hasCurriculum && type == 'CORE') {
      addReason('CORE kept only because it fits your career path or department');
    }

    final preferenceReasons = course['preferenceReasons'];
    if (preferenceReasons is Iterable) {
      for (final reason in preferenceReasons) {
        addReason(reason.toString());
      }
    }

    if (languagePreference == 'english' && _matchesInstructionLanguage(course, 'english')) {
      addReason('Matches English-taught preference');
    }

    if (languagePreference == 'chinese' && _matchesInstructionLanguage(course, 'chinese')) {
      addReason('Matches Chinese-taught preference');
    }

    if (_toInt(course['yearFitScore']) > 0) {
      addReason('Suitable for your current student year');
    }

    final limit = _toInt(course['limit']);
    if (limit > 0) {
      addReason('Has a valid class capacity');
    }

    if (matchedBy == 'fallback' && hasCurriculum) {
      addReason('Not an exact curriculum match, but kept as a useful fallback');
    }

    if (reasons.isEmpty) {
      addReason('Best available match from the real course list');
    }

    return reasons.take(5).toList();
  }

  int _baoBaoConfidenceScore(Map<String, dynamic> course) {
    var score = 0;

    score += _toInt(course['preferenceFitScore']);
    score += _toInt(course['yearFitScore']);

    if (_hasExactCurriculumMatch(course)) {
      score += 400;
    }

    final preferenceReasons = course['preferenceReasons'];
    if (preferenceReasons is Iterable &&
        preferenceReasons.any((reason) =>
            reason.toString().toLowerCase().contains('bao-bao memory'))) {
      score += 260;
    }

    if (_toInt(course['limit']) > 0) {
      score += 60;
    }

    return score;
  }

  String _baoBaoConfidenceLabel(Map<String, dynamic> course) {
    final score = _baoBaoConfidenceScore(course);

    if (score >= 650) return 'Strong match';
    if (score >= 300) return 'Good match';
    return 'Safe fallback';
  }

  String _friendlyBucketName(String bucket) {
    switch (bucket) {
      case 'DEPT_REQUIRED':
        return 'department required';
      case 'BASIC_CORE':
        return 'basic core';
      case 'CORE_COURSE':
        return 'core course';
      case 'PROFESSIONAL':
        return 'professional elective';
      case 'LAB':
        return 'lab';
      case 'GE':
        return 'general education';
      case 'LANGUAGE':
        return 'language';
      case 'FREE_ELECTIVE':
        return 'free elective';
      case 'SCHOOL_COMPULSORY':
        return 'school compulsory';
      default:
        return bucket.toLowerCase().replaceAll('_', ' ');
    }
  }

  List<Map<String, dynamic>> _filterByUserLanguagePreference({
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic>? userPreferences,
  }) {
    final prefs = _preferenceMap(userPreferences);
    final preferredLanguage = _normalizedInstructionLanguagePreference(
      (prefs['languagePreference'] ?? '').toString(),
    );

    if (preferredLanguage == null) {
      return courses;
    }

    final matchingCourses = courses.where((course) {
      return _matchesInstructionLanguage(course, preferredLanguage);
    }).toList();

    // Safety fallback: if Firestore language data is incomplete,
    // do not accidentally return zero courses.
    if (matchingCourses.isEmpty) {
      return courses;
    }

    return matchingCourses;
  }

  String? _normalizedInstructionLanguagePreference(String value) {
    final lower = value.toLowerCase();

    if (lower.contains('english') ||
        lower.contains('eng') ||
        lower.contains('英文') ||
        lower.contains('英語')) {
      return 'english';
    }

    if (lower.contains('chinese') ||
        lower.contains('mandarin') ||
        lower.contains('中文') ||
        lower.contains('華語') ||
        lower.contains('國語')) {
      return 'chinese';
    }

    return null;
  }

  bool _matchesInstructionLanguage(
    Map<String, dynamic> course,
    String language,
  ) {
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
    // Important: do NOT use the course title here.
    // A course can be English-taught or Chinese-taught even when the title
    // does not contain the word English/Chinese.
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

  List<Map<String, dynamic>> _attachUserPreferenceInsights({
    required List<Map<String, dynamic>> courses,
    required Map<String, dynamic>? userPreferences,
  }) {
    final prefs = _preferenceMap(userPreferences);

    return courses.map((course) {
      final copied = Map<String, dynamic>.from(course);
      final result = _preferenceFitForCourse(course, prefs);

      copied['preferenceFitScore'] = result.score;
      copied['preferenceReasons'] = result.reasons;

      return copied;
    }).toList();
  }


  List<Map<String, dynamic>> _applyPreferenceAwareCoreAndGeRules({
    required List<Map<String, dynamic>> courses,
    required bool hasCurriculum,
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? graduationData,
    required Map<String, dynamic>? userPreferences,
  }) {
    final prefs = _preferenceMap(userPreferences);
    final departmentHints = _departmentHintsFromData(
      userPreferences: prefs,
      graduationData: graduationData,
      curriculum: curriculum,
    );

    final geInterests = _stringListFromAny(prefs['geInterests']);
    final hasCareerPreferences = _stringListFromAny(prefs['careerPaths']).isNotEmpty;

    return courses.where((course) {
      final coreLike = _isCoreOrRequirementLike(course, hasCurriculum: hasCurriculum);
      final type = (course['type'] ?? '').toString().toUpperCase();
      final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();
      final geLike = bucket == 'GE' || type == 'GE';
      final electiveLike = type == 'ELECTIVE' || bucket == 'FREE_ELECTIVE';

      final careerOrDepartmentMatch = _courseMatchesCareerOrDepartment(
        course,
        prefs: prefs,
        departmentHints: departmentHints,
      );

      final geInterestMatch = _courseMatchesGeInterest(
        course,
        geInterests: geInterests,
      );

      if (coreLike) {
        if (hasCurriculum && _hasExactCurriculumMatch(course)) {
          return true;
        }

        return careerOrDepartmentMatch;
      }

      // When there is no uploaded curriculum, avoid filling the plan with
      // random GE/elective courses. GE should match GE interests, and
      // electives should match either career/department or GE interests.
      if (!hasCurriculum) {
        if (geLike && geInterests.isNotEmpty) {
          return geInterestMatch;
        }

        if (electiveLike) {
          // ELECTIVE recommendations may use GE interests, but they should not
          // become random department electives. If the user gave career paths,
          // career/department electives are allowed. If the user only gave GE
          // interests, electives must match those GE interests.
          if (geInterests.isNotEmpty && geInterestMatch) {
            return true;
          }

          if (hasCareerPreferences && careerOrDepartmentMatch) {
            return true;
          }

          return geInterests.isEmpty && !hasCareerPreferences;
        }
      }

      return true;
    }).map((course) {
      final copied = Map<String, dynamic>.from(course);
      final reasons = List<String>.from(
        (copied['preferenceReasons'] is Iterable)
            ? copied['preferenceReasons'] as Iterable
            : const [],
      );
      var score = _toInt(copied['preferenceFitScore']);

      final type = (copied['type'] ?? '').toString().toUpperCase();
      final bucket = (copied['curriculumBucket'] ?? '').toString().toUpperCase();

      if ((bucket == 'GE' || type == 'GE' || type == 'ELECTIVE') &&
          geInterests.isNotEmpty &&
          _courseMatchesGeInterest(copied, geInterests: geInterests)) {
        score += bucket == 'GE' || type == 'GE' ? 240 : 160;
        reasons.add(
          bucket == 'GE' || type == 'GE'
              ? 'GE preference match'
              : 'elective fits GE interest',
        );
      }

      final coreLike = _isCoreOrRequirementLike(copied, hasCurriculum: hasCurriculum);
      if (coreLike &&
          _courseMatchesCareerOrDepartment(
            copied,
            prefs: prefs,
            departmentHints: departmentHints,
          )) {
        score += hasCurriculum ? 220 : 320;
        reasons.add(
          hasCurriculum
              ? 'core/requirement course also fits career or department'
              : 'CORE course kept because it fits career or department',
        );
      }

      copied['preferenceFitScore'] = score;
      copied['preferenceReasons'] = reasons.toSet().toList();
      copied['baoBaoCorePolicy'] = hasCurriculum
          ? 'curriculum + career/department preference'
          : 'no curriculum: CORE requires career/department fit';

      return copied;
    }).toList();
  }

  bool _hasUsableCurriculum(Map<String, dynamic>? curriculum) {
    if (curriculum == null || curriculum.isEmpty) {
      return false;
    }

    final groups = curriculum['requirementGroups'];
    return groups is List && groups.isNotEmpty;
  }

  bool _isCoreOrRequirementLike(
    Map<String, dynamic> course, {
    required bool hasCurriculum,
  }) {
    final type = (course['type'] ?? '').toString().toUpperCase();
    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();

    if (type == 'CORE') {
      return true;
    }

    if (!hasCurriculum) {
      return false;
    }

    return {
      'DEPT_REQUIRED',
      'BASIC_CORE',
      'CORE_COURSE',
      'PROFESSIONAL',
      'LAB',
    }.contains(bucket);
  }

  bool _hasExactCurriculumMatch(Map<String, dynamic> course) {
    final matchedBy =
        (course['curriculumMatchedBy'] ?? '').toString().toLowerCase();

    return matchedBy.startsWith('acceptedcode:') || matchedBy == 'requiredname';
  }

  bool _courseMatchesCareerOrDepartment(
    Map<String, dynamic> course, {
    required Map<String, dynamic> prefs,
    required List<String> departmentHints,
  }) {
    final courseText = _normalizeText([
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['department'],
      course['type'],
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
      course['professor'],
    ].whereType<Object>().join(' '));

    for (final hint in departmentHints) {
      final normalizedHint = _normalizeText(hint);
      if (normalizedHint.isNotEmpty && courseText.contains(normalizedHint)) {
        return true;
      }
    }

    final profileKeywords = _searchProfileKeywords(
      prefs,
      const [
        'careerKeywords',
        'departmentKeywords',
        'coreCourseHints',
        'electiveHints',
      ],
    );

    for (final keyword in profileKeywords) {
      final normalizedKeyword = _normalizeText(keyword);
      if (normalizedKeyword.isNotEmpty && courseText.contains(normalizedKeyword)) {
        return true;
      }
    }

    // Fallback only when the AI preference profile is unavailable.
    final careerPaths = _stringListFromAny(prefs['careerPaths']);
    for (final career in careerPaths) {
      final careerText = _normalizeText(career);
      if (careerText.isNotEmpty && courseText.contains(careerText)) {
        return true;
      }
    }

    return false;
  }


  bool _courseMatchesGeInterest(
    Map<String, dynamic> course, {
    required List<String> geInterests,
  }) {
    if (geInterests.isEmpty) {
      return false;
    }

    final courseText = _normalizeText([
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['department'],
      course['type'],
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
      course['professor'],
      course['remarks'],
      course['note'],
    ].whereType<Object>().join(' '));

    for (final interest in geInterests) {
      final normalizedInterest = _normalizeText(interest);

      if (normalizedInterest.isEmpty) {
        continue;
      }

      // Direct match first, e.g. "Arts & Aesthetics" appears in metadata.
      if (courseText.contains(normalizedInterest)) {
        return true;
      }

      for (final keyword in _geInterestKeywords(normalizedInterest)) {
        final normalizedKeyword = _normalizeText(keyword);

        if (normalizedKeyword.isNotEmpty &&
            _containsMeaningfulPhrase(courseText, normalizedKeyword)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _containsMeaningfulPhrase(String text, String phrase) {
    if (phrase.length < 3) {
      return false;
    }

    if (text.contains(phrase)) {
      return true;
    }

    final phraseTokens = phrase
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 3)
        .toList();

    if (phraseTokens.isEmpty) {
      return false;
    }

    final textTokens = text.split(RegExp(r'\s+')).toSet();

    return phraseTokens.every(textTokens.contains);
  }

  List<String> _geInterestKeywords(String interestText) {
    final keywords = <String>{interestText};

    if (interestText.contains('natural') ||
        interestText.contains('science') ||
        interestText.contains('自然')) {
      keywords.addAll([
        'natural science',
        'science',
        'physics',
        'chemistry',
        'biology',
        'life science',
        'earth science',
        'environment',
        'environmental',
        'ecology',
        'energy',
        'astronomy',
        'geology',
        'climate',
        'technology',
        'engineering and technology',
        '物理',
        '化學',
        '生物',
        '生命科學',
        '地球',
        '環境',
        '生態',
        '能源',
        '天文',
        '科技',
      ]);
    }

    if (interestText.contains('humanities') ||
        interestText.contains('lit') ||
        interestText.contains('literature') ||
        interestText.contains('人文') ||
        interestText.contains('文學')) {
      keywords.addAll([
        'humanities',
        'literature',
        'philosophy',
        'history',
        'culture',
        'language and culture',
        'classics',
        'religion',
        'ethics',
        'knowledge and reality',
        'writing',
        'reading',
        '人文',
        '文學',
        '哲學',
        '歷史',
        '文化',
        '宗教',
        '倫理',
      ]);
    }

    if (interestText.contains('art') ||
        interestText.contains('aesthetic') ||
        interestText.contains('arts') ||
        interestText.contains('藝術') ||
        interestText.contains('美學')) {
      keywords.addAll([
        'arts',
        'art',
        'aesthetics',
        'music',
        'film',
        'cinema',
        'theater',
        'theatre',
        'drama',
        'design',
        'visual',
        'creative',
        'photography',
        // Do not include plain "architecture" here.
        // "Computer Architecture" is an EECS/CS course, not Arts & Aesthetics.
        '藝術',
        '美學',
        '音樂',
        '電影',
        '戲劇',
        '設計',
        '視覺',
        '創意',
        '攝影',
      ]);
    }

    if (interestText.contains('social') ||
        interestText.contains('society') ||
        interestText.contains('business') ||
        interestText.contains('economics') ||
        interestText.contains('社會') ||
        interestText.contains('經濟')) {
      keywords.addAll([
        'social science',
        'society',
        'sociology',
        'psychology',
        'politics',
        'law',
        'economics',
        'business',
        'management',
        'communication',
        '社會',
        '心理',
        '政治',
        '法律',
        '經濟',
        '管理',
        '傳播',
      ]);
    }

    return keywords.toList();
  }

  List<String> _departmentHintsFromPreferenceMap(Map<String, dynamic> prefs) {
    final hints = <String>{};

    void add(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return;
      hints.add(text);

      final upper = text.toUpperCase();
      if (upper.contains('EECS') || upper.contains('ELECTRICAL') || upper.contains('COMPUTER')) {
        hints.addAll(['EECS', 'CS', 'ECS', 'electrical engineering', 'computer science']);
      }
    }

    for (final entry in prefs.entries) {
      final key = entry.key.toString().toLowerCase();
      if (_looksLikeDepartmentKey(key)) {
        add(entry.value);
      }
    }

    return hints.toList();
  }

  List<String> _departmentHintsFromData({
    required Map<String, dynamic> userPreferences,
    required Map<String, dynamic>? graduationData,
    required Map<String, dynamic>? curriculum,
  }) {
    final hints = <String>{..._departmentHintsFromPreferenceMap(userPreferences)};

    void scan(dynamic value) {
      if (value == null) return;

      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();
          final rawValue = entry.value;

          if (_looksLikeDepartmentKey(key)) {
            final text = rawValue?.toString().trim() ?? '';
            if (text.isNotEmpty && text.length <= 80) {
              hints.add(text);
            }
          }

          scan(rawValue);
        }
      } else if (value is List) {
        for (final item in value) {
          scan(item);
        }
      }
    }

    scan(graduationData);
    scan(curriculum);

    final expanded = <String>{};
    for (final hint in hints) {
      expanded.add(hint);
      final upper = hint.toUpperCase();
      final lower = hint.toLowerCase();

      if (upper.contains('EECS') ||
          lower.contains('electrical') ||
          lower.contains('computer science') ||
          lower.contains('computer')) {
        expanded.addAll([
          'EECS',
          'ECS',
          'CS',
          'electrical engineering',
          'computer science',
          '資訊',
          '電機',
        ]);
      }
    }

    return expanded
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _looksLikeDepartmentKey(String key) {
    return key.contains('department') ||
        key.contains('dept') ||
        key.contains('major') ||
        key.contains('program') ||
        key.contains('college') ||
        key.contains('學系') ||
        key.contains('科系') ||
        key.contains('系所');
  }

  Map<String, dynamic> _preferenceMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};

    final nested = raw['preferences'];

    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _searchProfileMap(Map<String, dynamic> prefs) {
    final rawProfile = prefs['baoBaoSearchProfile'];

    if (rawProfile is Map) {
      return Map<String, dynamic>.from(rawProfile);
    }

    return {};
  }

  List<String> _searchProfileKeywords(
    Map<String, dynamic> prefs,
    List<String> keys,
  ) {
    final profile = _searchProfileMap(prefs);
    if (profile.isEmpty) return const [];

    final result = <String>{};

    for (final key in keys) {
      result.addAll(_stringListFromAny(profile[key]));
    }

    return result
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  _PreferenceFitResult _preferenceFitForCourse(
    Map<String, dynamic> course,
    Map<String, dynamic> prefs,
  ) {
    int score = 0;
    final reasons = <String>[];

    final text = _normalizeText([
      course['id'],
      course['code'],
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['department'],
      course['type'],
      course['curriculumBucket'],
      course['curriculumCategory'],
      course['curriculumRequiredCourseName'],
    ].whereType<Object>().join(' '));

    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();

    final careerPaths = _stringListFromAny(prefs['careerPaths']);
    final geInterests = _stringListFromAny(prefs['geInterests']);
    final languagePreference =
        (prefs['languagePreference'] ?? '').toString().toLowerCase();

    final profileCareerKeywords = _searchProfileKeywords(
      prefs,
      const [
        'careerKeywords',
        'departmentKeywords',
        'coreCourseHints',
        'electiveHints',
      ],
    );

    if (profileCareerKeywords.isNotEmpty) {
      for (final keyword in profileCareerKeywords) {
        final normalizedKeyword = _normalizeText(keyword);

        if (normalizedKeyword.isNotEmpty && text.contains(normalizedKeyword)) {
          score += 220;
          reasons.add('matches AI-resolved career/profile hint');
          break;
        }
      }
    } else {
      // Fallback only when the AI preference profile is unavailable.
      // Do not expand careers with hardcoded job-specific mappings here.
      for (final career in careerPaths) {
        final careerText = _normalizeText(career);

        if (careerText.isNotEmpty && text.contains(careerText)) {
          score += 180;
          reasons.add('matches career goal: $career');
          break;
        }
      }
    }

    if (careerPaths.isNotEmpty &&
        {
          'DEPT_REQUIRED',
          'BASIC_CORE',
          'CORE_COURSE',
          'PROFESSIONAL',
          'LAB',
        }.contains(bucket)) {
      score += 120;
    }

    final type = (course['type'] ?? '').toString().toUpperCase();
    final canUseGeInterest = bucket == 'GE' || type == 'GE' || type == 'ELECTIVE';

    if (geInterests.isNotEmpty &&
        canUseGeInterest &&
        _courseMatchesGeInterest(course, geInterests: geInterests)) {
      score += bucket == 'GE' || type == 'GE' ? 260 : 170;
      reasons.add(
        bucket == 'GE' || type == 'GE'
            ? 'matches GE interest'
            : 'elective also matches GE interest',
      );
    }

    final departmentHints = _departmentHintsFromPreferenceMap(prefs);
    for (final departmentHint in departmentHints) {
      final hintText = _normalizeText(departmentHint);

      if (hintText.isNotEmpty && text.contains(hintText)) {
        score += 150;
        reasons.add('matches user department: $departmentHint');
        break;
      }
    }

    final preferredLanguage =
        _normalizedInstructionLanguagePreference(languagePreference);

    if (preferredLanguage == 'english' &&
        _matchesInstructionLanguage(course, 'english')) {
      score += 180;
      reasons.add('matches English-taught preference');
    }

    if (preferredLanguage == 'chinese' &&
        _matchesInstructionLanguage(course, 'chinese')) {
      score += 120;
      reasons.add('matches Chinese-taught preference');
    }

    return _PreferenceFitResult(
      score: score,
      reasons: reasons.toSet().toList(),
    );
  }

  List<String> _careerKeywords(String careerText) {
    final cleaned = careerText.trim();
    return cleaned.isEmpty ? const [] : [cleaned];
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

    if (text.isEmpty) return [];

    return [text];
  }

  List<Map<String, dynamic>> _getAvailableCourses(
    List<Map<String, dynamic>> courseCatalog,
  ) {
    return courseCatalog.where((course) {
      final code = (course['code'] ?? '').toString().trim();
      final id = (course['id'] ?? '').toString().trim();
      final title = (course['title'] ?? '').toString().toLowerCase();
      final credits = _toInt(course['credits']);
      final limit = _toInt(course['limit']);

      if (code.isEmpty && id.isEmpty) return false;
      if (credits <= 0) return false;
      if (limit <= 0) return false;

      final badWords = [
        'thesis',
        'seminar',
        'colloquium',
        'research',
        'dissertation',
        'lab rotation',
        'independent study',
        'independent research',
        '論文',
        '研究',
        '書報',
      ];

      for (final word in badWords) {
        if (title.contains(word)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _attachCurriculumBuckets(
    List<Map<String, dynamic>> courses,
    Map<String, dynamic>? curriculum,
  ) {
    return courses.map((course) {
      final copied = Map<String, dynamic>.from(course);
      final match = _findCurriculumMatchForCourse(copied, curriculum);

      copied['curriculumBucket'] = match.bucket;
      copied['curriculumCategory'] = match.category;
      copied['curriculumRequiredCredits'] = match.requiredCredits;
      copied['curriculumRequiredCourseName'] = match.requiredCourseName;
      copied['curriculumMatchedBy'] = match.matchedBy;

      return copied;
    }).toList();
  }

  _CurriculumCourseMatch _findCurriculumMatchForCourse(
    Map<String, dynamic> course,
    Map<String, dynamic>? curriculum,
  ) {
    if (curriculum == null) {
      return _fallbackCurriculumMatch(course);
    }

    final groups = curriculum['requirementGroups'];

    if (groups is! List) {
      return _fallbackCurriculumMatch(course);
    }

    final courseCode = _normalizeCode(
      [
        course['code'],
        course['id'],
      ].whereType<Object>().join(' '),
    );

    final courseTitle = _normalizeText(
      [
        course['title'],
        course['titleZh'],
        course['titleEn'],
      ].whereType<Object>().join(' '),
    );

    _CurriculumCourseMatch? bestMatch;
    var bestPriority = 999;

    for (final group in groups) {
      if (group is! Map) continue;

      final categoryRaw = group['category']?.toString() ?? '';
      final descriptionRaw = group['description']?.toString() ?? '';
      final groupText = '$categoryRaw $descriptionRaw';
      final groupBucket = _bucketFromCategory(groupText);
      final requiredCredits = _toInt(group['requiredCredits']);
      final coursesRaw = group['courses'];

      if (coursesRaw is! List) continue;

      for (final requiredCourse in coursesRaw) {
        if (requiredCourse is! Map) continue;

        final courseBucket = _bucketFromRequiredCourse(
          groupBucket: groupBucket,
          requiredCourse: requiredCourse,
        );

        final requiredNameRaw = requiredCourse['name']?.toString() ?? '';
        final requiredName = _normalizeText(requiredNameRaw);
        final acceptedCodes = requiredCourse['acceptedCodes'];

        var matchedBy = '';

        if (acceptedCodes is List) {
          for (final acceptedCode in acceptedCodes) {
            final requiredCode = _normalizeCode(acceptedCode.toString());

            if (requiredCode.isNotEmpty && courseCode.contains(requiredCode)) {
              matchedBy = 'acceptedCode:$requiredCode';
              break;
            }
          }
        }

        if (matchedBy.isEmpty &&
            requiredName.isNotEmpty &&
            _requiredNameMatchesCourseTitle(requiredName, courseTitle)) {
          matchedBy = 'requiredName';
        }

        if (matchedBy.isEmpty) continue;

        final priority = _bucketPriority(courseBucket);

        if (bestMatch == null || priority < bestPriority) {
          bestPriority = priority;
          bestMatch = _CurriculumCourseMatch(
            bucket: courseBucket,
            category: categoryRaw,
            requiredCredits: requiredCredits,
            requiredCourseName: requiredNameRaw,
            matchedBy: matchedBy,
          );
        }
      }
    }

    return bestMatch ??
    _fallbackCurriculumMatch(
      course,
      allowCoreFallback: false,
    );
  }

  _CurriculumCourseMatch _fallbackCurriculumMatch(
    Map<String, dynamic> course, {
    bool allowCoreFallback = true,
  }) {
    final bucket = _fallbackBucketFromCourse(
      course,
      allowCoreFallback: allowCoreFallback,
    );

    return _CurriculumCourseMatch(
      bucket: bucket,
      category: 'Fallback from course type/title',
      requiredCredits: 0,
      requiredCourseName: '',
      matchedBy: 'fallback',
    );
  }

  String _bucketFromRequiredCourse({
    required String groupBucket,
    required Map requiredCourse,
  }) {
    final name = _normalizeText(requiredCourse['name']?.toString() ?? '');
    final type = _normalizeText(requiredCourse['type']?.toString() ?? '');
    final remarks = _normalizeText(requiredCourse['remarks']?.toString() ?? '');
    final text = '$name $type $remarks';

    if (text.contains('core general') ||
        text.contains('general education') ||
        text.contains('通識')) {
      return 'GE';
    }

    if (text.contains('english') ||
        text.contains('chinese') ||
        text.contains('mandarin') ||
        text.contains('language') ||
        text.contains('英文') ||
        text.contains('中文') ||
        text.contains('華語') ||
        text.contains('大學中文')) {
      return 'LANGUAGE';
    }

    if (text.contains('physical education') ||
        text.contains('student service') ||
        text.contains('conduct') ||
        text.contains('體育') ||
        text.contains('服務學習') ||
        text.contains('操行')) {
      return 'SCHOOL_COMPULSORY';
    }

    if (text.contains('elective course') ||
        text.contains('free elective') ||
        text.contains('選修')) {
      return 'FREE_ELECTIVE';
    }

    return groupBucket;
  }

  String _bucketFromCategory(String value) {
    final text = _normalizeText(value);

    if (text.contains('department required') ||
        text.contains('系定必修')) {
      return 'DEPT_REQUIRED';
    }

    if (text.contains('basic core') ||
        text.contains('基礎選修')) {
      return 'BASIC_CORE';
    }

    if ((text.contains('core course') || text.contains('core courses')) &&
        !text.contains('general education') &&
        !text.contains('core general')) {
      return 'CORE_COURSE';
    }

    if (text.contains('核心選修')) {
      return 'CORE_COURSE';
    }

    if (text.contains('professional') ||
        text.contains('專業選修')) {
      return 'PROFESSIONAL';
    }

    if (text.contains('lab') ||
        text.contains('laboratory') ||
        text.contains('實驗')) {
      return 'LAB';
    }

    if (text.contains('free elective') ||
        text.contains('其餘選修')) {
      return 'FREE_ELECTIVE';
    }

    if (text.contains('general education') ||
        text.contains('core general') ||
        text.contains('ge') ||
        text.contains('通識')) {
      return 'GE';
    }

    if (text.contains('english') ||
        text.contains('chinese') ||
        text.contains('mandarin') ||
        text.contains('language') ||
        text.contains('英文') ||
        text.contains('中文') ||
        text.contains('華語')) {
      return 'LANGUAGE';
    }

    if (text.contains('compulsory') ||
        text.contains('校定必修')) {
      return 'SCHOOL_COMPULSORY';
    }

    return 'UNKNOWN';
  }

  String _fallbackBucketFromCourse(
    Map<String, dynamic> course, {
    bool allowCoreFallback = true,
  }) {
    final type = (course['type'] ?? '').toString().toUpperCase();
    final department = (course['department'] ?? '').toString().toUpperCase();

    final title = _normalizeText(
      [
        course['title'],
        course['titleZh'],
        course['titleEn'],
      ].whereType<Object>().join(' '),
    );

    if (type == 'GE' || department == 'GE') {
      return 'GE';
    }

    if (title.contains('english') ||
        title.contains('chinese') ||
        title.contains('japanese') ||
        title.contains('mandarin') ||
        title.contains('language') ||
        title.contains('英文') ||
        title.contains('中文') ||
        title.contains('日文') ||
        title.contains('華語')) {
      return 'LANGUAGE';
    }

    // Important:
    // Do NOT call random CORE courses "CORE_COURSE" when curriculum exists.
    // Only actual curriculum matches should become CORE_COURSE.
    if (allowCoreFallback && type == 'CORE') {
      return 'CORE_COURSE';
    }

    if (type == 'ELECTIVE') {
      return 'FREE_ELECTIVE';
    }

    return 'UNKNOWN';
  }

  bool _requiredNameMatchesCourseTitle(
    String requiredName,
    String courseTitle,
  ) {
    if (requiredName.isEmpty || courseTitle.isEmpty) return false;

    if (courseTitle.contains(requiredName) || requiredName.contains(courseTitle)) {
      return true;
    }

    final reqTokens = _curriculumNameTokens(requiredName);
    final titleTokens = _curriculumNameTokens(courseTitle);

    if (reqTokens.isEmpty || titleTokens.isEmpty) return false;

    var matched = 0;

    for (final token in reqTokens) {
      if (titleTokens.contains(token)) {
        matched++;
      }
    }

    if (reqTokens.length <= 2) {
      return matched == reqTokens.length;
    }

    return matched >= (reqTokens.length * 0.65).ceil();
  }

  List<String> _curriculumNameTokens(String text) {
    const weakTokens = {
      'course',
      'courses',
      'class',
      'classes',
      'introduction',
      'intro',
      'basic',
      'general',
      'and',
      'the',
      'of',
      'for',
      'to',
      'in',
      'on',
      'i',
      'ii',
      'iii',
      'iv',
      '一',
      '二',
      '三',
    };

    return text
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .where((token) => !weakTokens.contains(token))
        .toSet()
        .toList();
  }

  int _bucketPriority(String bucket) {
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
      case 'FREE_ELECTIVE':
        return 8;
      case 'SCHOOL_COMPULSORY':
        return 9;
      default:
        return 99;
    }
  }

  Set<String> _getCompletedCourses(Map<String, dynamic>? graduationData) {
    if (graduationData == null) return {};

    final blocked = <String>{};

    void addCourseIdentity({
      dynamic code,
      dynamic title,
    }) {
      final keys = _courseIdentityKeysFromValues(
        code: code,
        title: title,
      );

      blocked.addAll(keys);
    }

    bool _gradeBlocksRecommendation(dynamic grade) {
      final text = grade?.toString().trim().toLowerCase() ?? '';

      if (text.isEmpty) return false;

      if (text.contains('fail') ||
          text.contains('failed') ||
          text.contains('not passed') ||
          text.contains('未通過') ||
          text.contains('不及格')) {
        return false;
      }

      return RegExp(r'^(a\+?|a-|b\+?|b-|c\+?|c-|d\+?|d-|p|s)$')
              .hasMatch(text) ||
          RegExp(r'^\d{2,3}$').hasMatch(text) ||
          text.contains('pass') ||
          text.contains('passed') ||
          text.contains('通過') ||
          text.contains('抵免');
    }

    void scan(dynamic value) {
      if (value == null) return;

      if (value is Map) {
        final status = _pickMapValue(value, [
          'status',
          'courseStatus',
          'state',
          'progress',
          'result',
        ])?.toString();

        final grade = _pickMapValue(value, [
          'grade',
          'finalGrade',
          'letterGrade',
          'score',
          '成績',
        ]);

        final code = _pickMapValue(value, [
          'code',
          'courseCode',
          'courseNo',
          'courseNumber',
          'subjectCode',
        ]);

        final title = _pickMapValue(value, [
          'title',
          'courseTitle',
          'courseName',
          'name',
          'englishName',
          'chineseName',
        ]);

        final hasCourseIdentity = code != null || title != null;

        final shouldBlock =
            (status != null && _statusBlocksRecommendation(status)) ||
            _gradeBlocksRecommendation(grade);

        if (hasCourseIdentity && shouldBlock) {
          addCourseIdentity(
            code: code,
            title: title,
          );
        }

        for (final item in value.values) {
          scan(item);
        }
      } else if (value is List) {
        for (final item in value) {
          scan(item);
        }
      } else if (value is String) {
        final codeMatches = RegExp(r'[A-Z]{2,8}\s*\d{3,6}')
            .allMatches(value.toUpperCase());

        for (final match in codeMatches) {
          blocked.add(_normalizeCode(match.group(0) ?? ''));
        }

        final normalizedTitle = _canonicalCourseTitleKey(value);

        if (normalizedTitle.isNotEmpty) {
          blocked.add(normalizedTitle);
        }
      }
    }

    scan(graduationData);

    print('Bao-Bao blocked completed/in-progress keys: $blocked');

    return blocked;
  }

  Set<String> _courseIdentityKeysFromValues({
    dynamic code,
    dynamic title,
  }) {
    final keys = <String>{};

    final normalizedCode = _normalizeCode(code?.toString() ?? '');

    if (normalizedCode.isNotEmpty) {
      keys.add(normalizedCode);

      final shortCodeMatches =
          RegExp(r'[A-Z]{2,8}\d{3,5}').allMatches(normalizedCode);

      for (final match in shortCodeMatches) {
        final code = match.group(0);

        if (code != null && code.isNotEmpty) {
          keys.add(code);
        }
      }
    }

    keys.addAll(_titleIdentityKeys(title?.toString() ?? ''));

    return keys;
  }

  String _canonicalCourseTitleKey(String value) {
    var text = _normalizeText(value);

    if (text.isEmpty) return '';

    text = text
        .replaceAll(RegExp(r'\bintro\b'), 'introduction')
        .replaceAll(RegExp(r'\bprog\b'), 'programming');

    text = text
        .replaceAll(RegExp(r'\biii\b'), '3')
        .replaceAll(RegExp(r'\bii\b'), '2')
        .replaceAll(RegExp(r'\bi\b'), '1')
        .replaceAll('三', '3')
        .replaceAll('二', '2')
        .replaceAll('一', '1');

    // I2P I: graduation may say Introduction to Programming (I),
    // but course card may say Introduction to Programming.
    text = text.replaceAll(
      RegExp(r'\bintroduction to programming 1\b'),
      'introduction to programming',
    );

    text = text.replaceAll(
      RegExp(r'\b計算機程式設計\s*1\b'),
      '計算機程式設計',
    );

    text = text.replaceAllMapped(
      RegExp(r'\bgeneral physics\s+[abc]\s+([123])\b'),
      (match) => 'general physics ${match.group(1)}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\bphysics\s+[abc]\s+([123])\b'),
      (match) => 'physics ${match.group(1)}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\bcalculus\s+[abc]\s+([123])\b'),
      (match) => 'calculus ${match.group(1)}',
    );

    // Common curriculum English/Chinese aliases.
    text = text
        .replaceAll('線性代數', 'linear algebra')
        .replaceAll('電磁學', 'electromagnetism')
        .replaceAll('電路學', 'electric circuits')
        .replaceAll('電子學 1', 'electronics 1')
        .replaceAll('電子學1', 'electronics 1')
        .replaceAll('電子學 2', 'electronics 2')
        .replaceAll('電子學2', 'electronics 2')
        .replaceAll('常微分方程', 'ordinary differential equations')
        .replaceAll('機率', 'probability')
        .replaceAll('訊號與系統', 'signals and systems')
        .replaceAll('資料結構', 'data structures')
        .replaceAll('作業系統', 'operating systems')
        .replaceAll('計算機結構', 'computer architecture');

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = _collapseRepeatedTitle(text);

    return text;
  }

  dynamic _pickMapValue(Map value, List<String> keys) {
    for (final key in keys) {
      if (value.containsKey(key) && value[key] != null) {
        return value[key];
      }
    }

    return null;
  }

  bool _statusBlocksRecommendation(String status) {
    final text = status
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    return text.contains('completed') ||
        text.contains('complete') ||
        text.contains('passed') ||
        text == 'pass' ||
        text.contains('in progress') ||
        text.contains('inprogress') ||
        text.contains('taking') ||
        text.contains('修習中') ||
        text.contains('已修') ||
        text.contains('通過') ||
        text.contains('抵免');
  }

  bool _courseMatchesBlockedList(
    Map<String, dynamic> course,
    Set<String> blockedCourses,
  ) {
    final identities = _courseIdentityKeys(course);

    for (final identity in identities) {
      if (blockedCourses.contains(identity)) {
        print(
          'Bao-Bao removed completed/in-progress course: '
          '${course['code']} ${course['title']} because matched $identity',
        );
        return true;
      }
    }

    return false;
  }

  List<String> _courseIdentityKeys(Map<String, dynamic> course) {
    final keys = <String>{};

    final rawCode = [
      course['code'],
      course['id'],
    ].whereType<Object>().join(' ');

    final normalizedCode = _normalizeCode(rawCode);

    if (normalizedCode.isNotEmpty) {
      keys.add(normalizedCode);

      final shortCodeMatches =
          RegExp(r'[A-Z]{2,8}\d{3,5}').allMatches(normalizedCode);

      for (final match in shortCodeMatches) {
        final code = match.group(0);

        if (code != null && code.isNotEmpty) {
          keys.add(code);
        }
      }
    }

    for (final value in [
      course['title'],
      course['titleZh'],
      course['titleEn'],
      course['curriculumRequiredCourseName'],
    ]) {
      keys.addAll(_titleIdentityKeys(value?.toString() ?? ''));
    }

    return keys.toList();
  }

  Set<String> _titleIdentityKeys(String value) {
    final keys = <String>{};

    final canonical = _canonicalCourseTitleKey(value);

    if (canonical.isNotEmpty) {
      keys.add(canonical);
      keys.addAll(_courseTitleAliases(canonical));
    }

    // Handles bilingual titles like:
    // 線性代數 Linear Algebra
    // 電路學 Electric Circuits
    final englishOnly = value
        .replaceAll(RegExp(r'[^A-Za-z0-9()ⅠⅡⅢⅣIVXivx\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final englishCanonical = _canonicalCourseTitleKey(englishOnly);

    if (englishCanonical.isNotEmpty) {
      keys.add(englishCanonical);
      keys.addAll(_courseTitleAliases(englishCanonical));
    }

    return keys;
  }

  Set<String> _courseTitleAliases(String canonicalTitle) {
    final aliases = <String>{};

    final title = canonicalTitle.toLowerCase().trim();

    // NTHU often displays I2P I as just "Introduction to Programming".
    // So if the student completed "Introduction to Programming (I)",
    // we should also block the course card "Introduction to Programming".
    if (title == 'introduction to programming') {
      aliases.add('introduction to programming 1');
      aliases.add('introduction to programming i');
      aliases.add('i2p');
      aliases.add('i2p 1');
      aliases.add('i2p i');
      aliases.add('intro to programming');
      aliases.add('intro to programming 1');
    }

    // But do NOT collapse I2P II into I2P I.
    if (title == 'introduction to programming 2') {
      aliases.add('introduction to programming ii');
      aliases.add('i2p 2');
      aliases.add('i2p ii');
      aliases.add('intro to programming 2');
    }

    return aliases;
  }

  String _collapseRepeatedTitle(String text) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();

    if (tokens.length.isEven && tokens.isNotEmpty) {
      final half = tokens.length ~/ 2;
      final first = tokens.take(half).join(' ');
      final second = tokens.skip(half).join(' ');

      if (first == second) {
        return first;
      }
    }

    return text;
  }

  List<Map<String, dynamic>> _dedupeSameCourse(
    List<Map<String, dynamic>> courses,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final course in courses) {
      final key = _courseDedupKey(course);

      if (key.isEmpty || !seen.contains(key)) {
        result.add(course);

        if (key.isNotEmpty) {
          seen.add(key);
        }
      }
    }

    return result;
  }

  String _courseDedupKey(Map<String, dynamic> course) {
    final title = _normalizeText(
      [
        course['title'],
        course['titleZh'],
        course['titleEn'],
      ].whereType<Object>().join(' '),
    );

    if (title.isNotEmpty) {
      return 'title:$title';
    }

    final code = _normalizeCode(
      course['code']?.toString() ?? course['id']?.toString() ?? '',
    );

    if (code.isNotEmpty) {
      return 'code:$code';
    }

    return '';
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

  BaoBaoPlanValidation _validatePlan({
    required List<Map<String, dynamic>> plannedCourses,
    required Set<String> completedCourses,
    required Map<String, dynamic>? curriculum,
  }) {
    final warnings = <String>[];
    final validCourseIds = <String>[];

    int totalCredits = 0;
    final occupiedSlots = <String, String>{};

    for (final course in plannedCourses) {
      final id = course['id']?.toString() ?? '';
      final code = _normalizeCode(course['code']?.toString() ?? id);
      final title = course['title']?.toString() ?? code;
      final credits = _toInt(course['credits']);

      totalCredits += credits;

      if (_courseMatchesBlockedList(course, completedCourses)) {
        warnings.add('$title may already be completed or in progress.');
        continue;
      }

      final slots = _courseScheduleSlotKeys(course);
      String? conflictWith;

      for (final slot in slots) {
        if (occupiedSlots.containsKey(slot)) {
          conflictWith = occupiedSlots[slot];
          break;
        }
      }

      if (conflictWith != null) {
        warnings.add('$title has a time conflict with $conflictWith.');
      } else {
        for (final slot in slots) {
          occupiedSlots[slot] = title;
        }
      }

      if (id.isNotEmpty) {
        validCourseIds.add(id);
      }
    }

    final curriculumMatches = _countCurriculumMatches(
      plannedCourses: plannedCourses,
      curriculum: curriculum,
    );

    final bucketCounts = _bucketCounts(plannedCourses);

    if (plannedCourses.isEmpty) {
      warnings.add('No courses were selected.');
    }

    final summaryParts = <String>[
      'Plan has ${plannedCourses.length} courses',
      '$totalCredits credits',
      '$curriculumMatches curriculum matches',
      'buckets: ${_formatBucketCounts(bucketCounts)}',
    ];

    if (warnings.isNotEmpty) {
      summaryParts.add('${warnings.length} warning(s)');
    }

    return BaoBaoPlanValidation(
      totalCredits: totalCredits,
      validCourseIds: validCourseIds,
      warnings: warnings,
      curriculumMatches: curriculumMatches,
      bucketCounts: bucketCounts,
      hasCriticalIssue: plannedCourses.isEmpty ||
          warnings.any((warning) => warning.toLowerCase().contains('time conflict')),
      summary: '${summaryParts.join(', ')}.',
    );
  }

  int _countCurriculumMatches({
    required List<Map<String, dynamic>> plannedCourses,
    required Map<String, dynamic>? curriculum,
  }) {
    if (!_hasUsableCurriculum(curriculum)) {
      return 0;
    }

    return plannedCourses.where(_hasExactCurriculumMatch).length;
  }

  Map<String, int> _bucketCounts(List<Map<String, dynamic>> courses) {
    final counts = <String, int>{};

    for (final course in courses) {
      final bucket = course['curriculumBucket']?.toString() ?? 'UNKNOWN';
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }

    return counts;
  }

  String _formatBucketCounts(Map<String, int> counts) {
    if (counts.isEmpty) return 'none';

    final ordered = counts.entries.toList()
      ..sort((a, b) => _bucketPriority(a.key).compareTo(_bucketPriority(b.key)));

    return ordered.map((entry) => '${entry.key}:${entry.value}').join(', ');
  }

  String _explainPlan({
    required String userMessage,
    required List<Map<String, dynamic>> plannedCourses,
    required Map<String, dynamic>? curriculum,
    required BaoBaoPlanValidation validation,
    required Set<String> completedCourses,
  }) {
    if (plannedCourses.isEmpty) {
      return 'Bao-Bao could not find a strong matching plan. Try asking with clearer details like course type, credits, department, time, or curriculum requirement.';
    }

    final hasCurriculum = _hasUsableCurriculum(curriculum);
    final hasCompletedData = completedCourses.isNotEmpty;

    final courseLines = plannedCourses.map((course) {
      final code = course['code']?.toString() ?? '';
      final title = course['title']?.toString() ?? 'Unknown course';
      final credits = course['credits']?.toString() ?? '';
      final type = course['type']?.toString() ?? '';
      final bucket = course['curriculumBucket']?.toString() ?? 'UNKNOWN';

      return '- $code $title ($credits credits, $type, bucket: $bucket)';
    }).join('\n');

    final warningText = validation.warnings.isEmpty
        ? 'No major warnings.'
        : validation.warnings.map((warning) => '- $warning').join('\n');

    return '''
Bao-Bao planned this using an agentic flow 🐼

I checked:
- Curriculum: ${hasCurriculum ? "available and mapped into buckets" : "not uploaded yet"}
- Available courses: checked
- Completed courses from graduation data: ${hasCompletedData ? "checked" : "not detected"}
- Curriculum bucket validation: ${hasCurriculum ? "checked" : "skipped until curriculum is uploaded"}

Recommended plan:
$courseLines

Validation summary:
- Total credits: ${validation.totalCredits}
- Curriculum matches: ${validation.curriculumMatches}
- Bucket counts: ${_formatBucketCounts(validation.bucketCounts)}
- Warnings:
$warningText
'''
        .trim();
  }


  int? _inferStudentYear({
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? graduationData,
    required List<Map<String, dynamic>> courseCatalog,
  }) {
    final currentAcademicYear = _inferCurrentAcademicYear(courseCatalog);
    final entryYear = _inferEntryYear(
      curriculum: curriculum,
      graduationData: graduationData,
    );

    if (currentAcademicYear != null && entryYear != null) {
      final year = currentAcademicYear - entryYear + 1;

      if (year >= 1 && year <= 6) {
        return year;
      }
    }

    final fromGraduation = _findStudentYearInData(graduationData);

    if (fromGraduation != null) {
      return fromGraduation;
    }

    return null;
  }

  int? _inferCurrentAcademicYear(List<Map<String, dynamic>> courseCatalog) {
    final years = <int>[];

    for (final course in courseCatalog) {
      final raw = [
        course['id'],
        course['code'],
      ].whereType<Object>().join(' ').toUpperCase();

      // NTHU course codes in this project often look like:
      // 11420EE203000, 11420CS342300, etc.
      // The first 3 digits are the academic year, e.g. 114.
      final prefixedMatches = RegExp(r'\b(1\d{2})\d{0,2}[A-Z]{1,8}')
          .allMatches(raw);

      for (final match in prefixedMatches) {
        final year = int.tryParse(match.group(1) ?? '');

        if (year != null) {
          years.add(year);
        }
      }
    }

    if (years.isEmpty) return null;

    years.sort();
    return years.last;
  }

  int? _inferEntryYear({
    required Map<String, dynamic>? curriculum,
    required Map<String, dynamic>? graduationData,
  }) {
    final preferredValues = <dynamic>[
      curriculum?['entryYear'],
      curriculum?['admissionYear'],
      curriculum?['schoolYear'],
      curriculum?['studentId'],
      curriculum?['accountStudentId'],
    ];

    int? parseFromValue(dynamic value) {
      final text = value?.toString() ?? '';

      if (text.trim().isEmpty) return null;

      // Student ID like 113006203 means entry/admission year 113.
      final studentIdMatch = RegExp(r'\b(1\d{2})\d{5,}\b').firstMatch(text);

      if (studentIdMatch != null) {
        return int.tryParse(studentIdMatch.group(1) ?? '');
      }

      // Direct ROC academic year like 113.
      final yearMatch = RegExp(r'\b(1\d{2})\b').firstMatch(text);

      if (yearMatch != null) {
        return int.tryParse(yearMatch.group(1) ?? '');
      }

      return null;
    }

    for (final value in preferredValues) {
      final year = parseFromValue(value);
      if (year != null) return year;
    }

    int? scanPreferredKeys(dynamic value) {
      if (value == null) return null;

      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();

          final looksLikeEntryField = key.contains('studentid') ||
              key.contains('student_id') ||
              key.contains('accountstudentid') ||
              key.contains('admission') ||
              key.contains('entry') ||
              key.contains('enroll') ||
              key.contains('入學') ||
              key.contains('學號');

          if (looksLikeEntryField) {
            final year = parseFromValue(entry.value);
            if (year != null) return year;
          }
        }

        for (final item in value.values) {
          final nested = scanPreferredKeys(item);
          if (nested != null) return nested;
        }
      } else if (value is List) {
        for (final item in value) {
          final nested = scanPreferredKeys(item);
          if (nested != null) return nested;
        }
      }

      return null;
    }

    final preferredFromGraduation = scanPreferredKeys(graduationData);
    if (preferredFromGraduation != null) return preferredFromGraduation;

    int? scanAnyStudentId(dynamic value) {
      if (value == null) return null;

      if (value is String || value is num) {
        final text = value.toString();
        final match = RegExp(r'\b(1\d{2})\d{5,}\b').firstMatch(text);
        if (match != null) return int.tryParse(match.group(1) ?? '');
      } else if (value is Map) {
        for (final item in value.values) {
          final nested = scanAnyStudentId(item);
          if (nested != null) return nested;
        }
      } else if (value is List) {
        for (final item in value) {
          final nested = scanAnyStudentId(item);
          if (nested != null) return nested;
        }
      }

      return null;
    }

    return scanAnyStudentId(graduationData);
  }

  int? _findStudentYearInData(dynamic data) {
    if (data == null) return null;

    int? parseYearText(String text) {
      final lower = text.toLowerCase();

      if (lower.contains('freshman') ||
          lower.contains('first year') ||
          lower.contains('year 1') ||
          lower.contains('一年級')) {
        return 1;
      }

      if (lower.contains('sophomore') ||
          lower.contains('second year') ||
          lower.contains('year 2') ||
          lower.contains('二年級')) {
        return 2;
      }

      if (lower.contains('junior') ||
          lower.contains('third year') ||
          lower.contains('year 3') ||
          lower.contains('三年級')) {
        return 3;
      }

      if (lower.contains('senior') ||
          lower.contains('fourth year') ||
          lower.contains('year 4') ||
          lower.contains('四年級')) {
        return 4;
      }

      return null;
    }

    if (data is String) {
      return parseYearText(data);
    }

    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();

        if (key.contains('year') ||
            key.contains('grade') ||
            key.contains('classyear') ||
            key.contains('年級')) {
          final parsed = parseYearText(entry.value.toString());
          if (parsed != null) return parsed;

          final number = int.tryParse(entry.value.toString());
          if (number != null && number >= 1 && number <= 6) {
            return number;
          }
        }

        final nested = _findStudentYearInData(entry.value);
        if (nested != null) return nested;
      }
    }

    if (data is List) {
      for (final item in data) {
        final nested = _findStudentYearInData(item);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _attachYearFit({
    required List<Map<String, dynamic>> courses,
    required int? studentYear,
  }) {
    return courses.map((course) {
      final copied = Map<String, dynamic>.from(course);
      final courseLevel = _courseLevelFromCourse(course);

      copied['studentYear'] = studentYear;
      copied['courseYearLevel'] = courseLevel;
      copied['yearFitScore'] = _yearFitScore(
        course: copied,
        studentYear: studentYear,
        courseLevel: courseLevel,
      );

      return copied;
    }).toList();
  }

  int? _courseLevelFromCourse(Map<String, dynamic> course) {
    final raw = [
      course['code'],
      course['id'],
    ].whereType<Object>().join(' ').toUpperCase();

    // Examples:
    // 11420EE203000 -> EE203000 -> level 2
    // CS 342300 -> level 3
    final matches = RegExp(r'[A-Z]{2,8}\s*([1-6])\d{2,5}').allMatches(raw);

    for (final match in matches) {
      final level = int.tryParse(match.group(1) ?? '');

      if (level != null && level >= 1 && level <= 6) {
        return level;
      }
    }

    return null;
  }

  int _yearFitScore({
    required Map<String, dynamic> course,
    required int? studentYear,
    required int? courseLevel,
  }) {
    if (studentYear == null || courseLevel == null) {
      return 0;
    }

    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();

    final isCurriculumImportantBucket = {
      'DEPT_REQUIRED',
      'BASIC_CORE',
      'CORE_COURSE',
      'PROFESSIONAL',
      'LAB',
    }.contains(bucket);

    if (!isCurriculumImportantBucket) {
      return 0;
    }

    if (courseLevel == studentYear) {
      return 3000;
    }

    if (courseLevel == studentYear - 1) {
      return 1800;
    }

    if (courseLevel < studentYear - 1) {
      return 800;
    }

    if (courseLevel == studentYear + 1) {
      return -1200;
    }

    if (courseLevel >= studentYear + 2) {
      return -5000;
    }

    return 0;
  }

  bool _isTooAdvancedForStudentYear(
    Map<String, dynamic> course,
    int? studentYear,
  ) {
    if (studentYear == null) return false;

    final courseLevel = _toInt(course['courseYearLevel']);

    if (courseLevel <= 0) return false;

    final bucket = (course['curriculumBucket'] ?? '').toString().toUpperCase();

    final shouldControlByYear = {
      'DEPT_REQUIRED',
      'BASIC_CORE',
      'CORE_COURSE',
      'PROFESSIONAL',
      'LAB',
    }.contains(bucket);

    if (!shouldControlByYear) return false;

    // Example: sophomore should not receive 4th-year curriculum courses.
    // Junior should not receive 5th/6th-year courses.
    if (courseLevel >= studentYear + 2) {
      print(
        'Bao-Bao removed too-advanced course for year $studentYear: '
        '${course['code']} ${course['title']} level=$courseLevel bucket=$bucket',
      );
      return true;
    }

    return false;
  }

  String _normalizeCode(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizeText(String value) {
    return value
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

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    final match = RegExp(r'\d+').firstMatch(value.toString());

    if (match == null) return 0;

    return int.tryParse(match.group(0) ?? '') ?? 0;
  }
}

class _CurriculumCourseMatch {
  final String bucket;
  final String category;
  final int requiredCredits;
  final String requiredCourseName;
  final String matchedBy;

  const _CurriculumCourseMatch({
    required this.bucket,
    required this.category,
    required this.requiredCredits,
    required this.requiredCourseName,
    required this.matchedBy,
  });
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
