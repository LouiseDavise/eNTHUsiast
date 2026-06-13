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
  }) async {
    final trace = <BaoBaoAgentStep>[];

    final hasCurriculum = curriculum != null && curriculum.isNotEmpty;

    trace.add(
      BaoBaoAgentStep(
        name: 'getCurriculum',
        status: hasCurriculum ? 'done' : 'skipped',
        message: hasCurriculum
            ? 'Curriculum found. Bao-Bao will map courses into curriculum buckets.'
            : 'No curriculum uploaded yet. Bao-Bao will use CORE / ELECTIVE / GE only.',
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

   final bucketCountsBeforeFilter = _bucketCounts(preferenceAwareCourses);

    trace.add(
      BaoBaoAgentStep(
        name: 'mapCoursesToCurriculumBuckets',
        status: hasCurriculum ? 'done' : 'skipped',
        message: hasCurriculum
            ? 'Mapped courses to curriculum buckets: ${_formatBucketCounts(bucketCountsBeforeFilter)}.'
            : 'Skipped bucket mapping because no curriculum was found.',
      ),
    );

    final availableCourses = _dedupeSameCourse(
      preferenceAwareCourses.where((course) {
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
      const BaoBaoAgentStep(
        name: 'planCourse',
        status: 'running',
        message: 'Generating candidate plan using bucketed courses...',
      ),
    );

    final recommendedIds = await aiApi.askBaoBaoRecommendedCourseIds(
      userMessage: userMessage,
      courseCatalog: availableCourses,
      curriculum: curriculum,
      userPreferences: userPreferences,
    );

    final recommendedCourses = availableCourses.where((course) {
      final id = course['id']?.toString() ?? '';
      final code = course['code']?.toString() ?? '';

      return recommendedIds.contains(id) || recommendedIds.contains(code);
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

  Map<String, dynamic> _preferenceMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};

    final nested = raw['preferences'];

    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    return Map<String, dynamic>.from(raw);
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

    for (final career in careerPaths) {
      final careerText = _normalizeText(career);
      final careerKeywords = _careerKeywords(careerText);

      for (final keyword in careerKeywords) {
        final normalizedKeyword = _normalizeText(keyword);

        if (normalizedKeyword.isNotEmpty && text.contains(normalizedKeyword)) {
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

    if (geInterests.isNotEmpty && bucket == 'GE') {
      for (final interest in geInterests) {
        final interestText = _normalizeText(interest);

        if (interestText.isNotEmpty && text.contains(interestText)) {
          score += 220;
          reasons.add('matches GE interest: $interest');
          break;
        }
      }
    }

    if (languagePreference.contains('english')) {
      if (text.contains('english') ||
          text.contains('英語') ||
          text.contains('英文') ||
          text.contains('english taught')) {
        score += 180;
        reasons.add('matches English-taught preference');
      }
    }

    if (languagePreference.contains('chinese')) {
      if (text.contains('chinese') ||
          text.contains('中文') ||
          text.contains('華語')) {
        score += 120;
        reasons.add('matches Chinese-taught preference');
      }
    }

    return _PreferenceFitResult(
      score: score,
      reasons: reasons.toSet().toList(),
    );
  }

  List<String> _careerKeywords(String careerText) {
    final keywords = <String>{careerText};

    if (careerText.contains('software')) {
      keywords.addAll([
        'software',
        'programming',
        'data structures',
        'algorithms',
        'database',
        'operating systems',
        'computer networks',
        'software studio',
        'computer architecture',
        'web',
        'app',
        'backend',
      ]);
    }

    if (careerText.contains('devops') ||
        careerText.contains('sre') ||
        careerText.contains('cloud')) {
      keywords.addAll([
        'devops',
        'cloud',
        'network',
        'computer networks',
        'operating systems',
        'linux',
        'system',
        'distributed',
        'database',
        'security',
        'software',
        'backend',
        'web',
        'computer architecture',
      ]);
    }

    if (careerText.contains('ai') ||
        careerText.contains('machine learning') ||
        careerText.contains('data')) {
      keywords.addAll([
        'machine learning',
        'artificial intelligence',
        'data',
        'statistics',
        'probability',
        'linear algebra',
        'algorithm',
        'python',
      ]);
    }

    if (careerText.contains('hardware') ||
        careerText.contains('embedded') ||
        careerText.contains('chip')) {
      keywords.addAll([
        'logic design',
        'electronics',
        'electric circuits',
        'computer architecture',
        'embedded',
        'microelectronics',
        'signals and systems',
      ]);
    }

    return keywords.toList();
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

      if (code.isEmpty && id.isEmpty) return false;
      if (credits <= 0) return false;

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

  BaoBaoPlanValidation _validatePlan({
    required List<Map<String, dynamic>> plannedCourses,
    required Set<String> completedCourses,
    required Map<String, dynamic>? curriculum,
  }) {
    final warnings = <String>[];
    final validCourseIds = <String>[];

    int totalCredits = 0;

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
      hasCriticalIssue: plannedCourses.isEmpty,
      summary: '${summaryParts.join(', ')}.',
    );
  }

  int _countCurriculumMatches({
    required List<Map<String, dynamic>> plannedCourses,
    required Map<String, dynamic>? curriculum,
  }) {
    return plannedCourses.where((course) {
      final bucket = course['curriculumBucket']?.toString() ?? 'UNKNOWN';
      return bucket != 'UNKNOWN';
    }).length;
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

    final hasCurriculum = curriculum != null;
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
- Curriculum bucket validation: checked

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
