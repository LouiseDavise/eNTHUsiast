import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/courses_planner_model.dart';

class BaoBaoMemoryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BaoBaoMemoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<DocumentReference<Map<String, dynamic>>?> _currentCcxpUserRef() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final usersRef = _firestore.collection('ccxpUsers');

    final byAuthUid = await usersRef
        .where('authUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (byAuthUid.docs.isNotEmpty) {
      return byAuthUid.docs.first.reference;
    }

    final directDoc = await usersRef.doc(user.uid).get();
    if (directDoc.exists) {
      return directDoc.reference;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final byEmail = await usersRef
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (byEmail.docs.isNotEmpty) {
        return byEmail.docs.first.reference;
      }
    }

    return null;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _memoryDocRef() async {
    final userRef = await _currentCcxpUserRef();
    if (userRef == null) return null;

    // Same level as coursePlanner/myPlan.
    // ccxpUsers/{profileDoc}/coursePlanner/baoBaoMemory
    return userRef.collection('coursePlanner').doc('baoBaoMemory');
  }

  Future<Map<String, dynamic>> fetchMemory() async {
    final ref = await _memoryDocRef();
    if (ref == null) return {};

    final snapshot = await ref.get();
    final data = snapshot.data();

    if (data == null) return {};

    return _cleanMemoryData(Map<String, dynamic>.from(data));
  }

  Future<void> rememberAcceptedCourse(
    PlannerCourse course, {
    List<String> reasons = const [],
  }) async {
    final ref = await _memoryDocRef();
    if (ref == null) return;

    final keywordHints = _keywordHintsForCourse(course);

    await ref.set(
      {
        'likedCourseIds': FieldValue.arrayUnion([course.id]),
        'likedCourseCodes': FieldValue.arrayUnion([course.code]),
        'likedCourseTitles': FieldValue.arrayUnion([course.title]),
        'preferredKeywords': FieldValue.arrayUnion(keywordHints),
        'lastAcceptedCourseId': course.id,
        'lastAcceptedCourseTitle': course.title,
        'lastAcceptedReasons': reasons.take(5).toList(),
        'acceptedRecommendationCount': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendAction(
      type: 'accepted_course',
      course: course,
      extra: {
        'reasons': reasons.take(5).toList(),
        'keywordHints': keywordHints,
      },
    );
  }

  Future<void> rememberRejectedCourse(
    PlannerCourse course, {
    String reason = 'User removed or rejected this Bao-Bao recommendation.',
  }) async {
    final ref = await _memoryDocRef();
    if (ref == null) return;

    final avoidHints = _avoidHintsForCourse(course);

    await ref.set(
      {
        'dislikedCourseIds': FieldValue.arrayUnion([course.id]),
        'dislikedCourseCodes': FieldValue.arrayUnion([course.code]),
        'dislikedCourseTitles': FieldValue.arrayUnion([course.title]),
        'avoidKeywords': FieldValue.arrayUnion(avoidHints),
        'lastRejectedCourseId': course.id,
        'lastRejectedCourseTitle': course.title,
        'lastRejectedReason': reason,
        'rejectedRecommendationCount': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendAction(
      type: 'rejected_course',
      course: course,
      extra: {
        'reason': reason,
        'avoidHints': avoidHints,
      },
    );
  }

  Future<void> rememberAvoidKeyword(String rawKeyword) async {
    final keyword = _cleanKeyword(rawKeyword);
    if (keyword.isEmpty || !_isUsefulManualKeyword(keyword)) return;

    final ref = await _memoryDocRef();
    if (ref == null) return;

    await ref.set(
      {
        'avoidKeywords': FieldValue.arrayUnion([keyword]),
        'lastAvoidKeyword': keyword,
        'manualMemoryCount': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendSimpleAction(
      type: 'avoid_keyword',
      data: {'keyword': keyword},
    );
  }

  Future<void> rememberPreferredKeyword(String rawKeyword) async {
    final keyword = _cleanKeyword(rawKeyword);
    if (keyword.isEmpty || !_isUsefulManualKeyword(keyword)) return;

    final ref = await _memoryDocRef();
    if (ref == null) return;

    await ref.set(
      {
        'preferredKeywords': FieldValue.arrayUnion([keyword]),
        'lastPreferredKeyword': keyword,
        'manualMemoryCount': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendSimpleAction(
      type: 'preferred_keyword',
      data: {'keyword': keyword},
    );
  }

  Future<void> rememberRecommendationSession({
    required List<String> courseIds,
    String? message,
  }) async {
    final ref = await _memoryDocRef();
    if (ref == null || courseIds.isEmpty) return;

    await ref.set(
      {
        'lastRecommendationCourseIds': courseIds.take(20).toList(),
        'lastRecommendationMessage': message,
        'lastRecommendationAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendSimpleAction(
      type: 'recommendation_session',
      data: {
        'courseIds': courseIds.take(20).toList(),
        'message': message,
      },
    );
  }

  Future<void> clearMemory() async {
    final ref = await _memoryDocRef();
    if (ref == null) return;

    await ref.set(
      {
        'likedCourseIds': <String>[],
        'likedCourseCodes': <String>[],
        'likedCourseTitles': <String>[],
        'dislikedCourseIds': <String>[],
        'dislikedCourseCodes': <String>[],
        'dislikedCourseTitles': <String>[],
        'preferredKeywords': <String>[],
        'avoidKeywords': <String>[],
        'memoryResetAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _appendSimpleAction(
      type: 'clear_memory',
      data: const {},
    );
  }

  Map<String, dynamic> _cleanMemoryData(Map<String, dynamic> data) {
    final cleaned = Map<String, dynamic>.from(data);

    cleaned['avoidKeywords'] = _cleanKeywordList(cleaned['avoidKeywords']);
    cleaned['preferredKeywords'] = _cleanKeywordList(cleaned['preferredKeywords']);

    return cleaned;
  }

  List<String> _cleanKeywordList(dynamic value) {
    if (value is! Iterable) return const [];

    return value
        .map((item) => _cleanKeyword(item.toString()))
        .where(_isUsefulManualKeyword)
        .toSet()
        .toList();
  }

  bool _isUsefulManualKeyword(String keyword) {
    final lower = keyword.toLowerCase().trim();

    if (lower.isEmpty) return false;

    // Avoid saving Bao-Bao's own internal planning rules as user memory.
    final internalPlanningWords = [
      'completed',
      'in-progress',
      'in progress',
      'duplicated sections',
      'duplicate sections',
      'schedule conflicts',
      'too advanced',
      'real course list',
      'graduation data',
      'curriculum buckets',
      'course list instead',
    ];

    for (final word in internalPlanningWords) {
      if (lower.contains(word)) return false;
    }

    // Real memory keywords should be short preference objects,
    // such as "business english", "economics", "ai", or "early morning".
    final wordCount = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount > 6) return false;

    return true;
  }

  Future<void> _appendAction({
    required String type,
    required PlannerCourse course,
    Map<String, dynamic> extra = const {},
  }) async {
    await _appendSimpleAction(
      type: type,
      data: {
        'courseId': course.id,
        'courseCode': course.code,
        'courseTitle': course.title,
        'courseType': course.type,
        'department': course.department,
        ...extra,
      },
    );
  }

  Future<void> _appendSimpleAction({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final ref = await _memoryDocRef();
    if (ref == null) return;

    await ref.collection('actions').add({
      'type': type,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> _keywordHintsForCourse(PlannerCourse course) {
    final result = <String>{};

    void add(String value) {
      final cleaned = _cleanKeyword(value);
      if (cleaned.isNotEmpty) result.add(cleaned);
    }

    add(course.department);
    add(course.type);
    add(course.title);

    final title = course.title.toLowerCase();
    if (title.contains('machine learning') || title.contains('artificial intelligence')) {
      add('ai');
      add('machine learning');
    }
    if (title.contains('software') || title.contains('programming')) {
      add('software');
      add('programming');
    }
    if (title.contains('data')) {
      add('data');
    }
    if (title.contains('network')) {
      add('computer networks');
    }
    if (title.contains('architecture') && title.contains('computer')) {
      add('computer architecture');
    }

    return result.take(8).toList();
  }

  List<String> _avoidHintsForCourse(PlannerCourse course) {
    final result = <String>{};

    void add(String value) {
      final cleaned = _cleanKeyword(value);
      if (cleaned.isNotEmpty) result.add(cleaned);
    }

    add(course.title);

    final title = course.title.toLowerCase();
    if (title.contains('business english')) {
      add('business english');
    } else if (title.contains('english')) {
      add('english course');
    }

    if (title.contains('economics')) {
      add('economics');
    }

    return result.take(6).toList();
  }

  String _cleanKeyword(String raw) {
    var text = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff &+.-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final prefixes = [
      'dont recommend',
      "don't recommend",
      'do not recommend',
      'avoid',
      'i dislike',
      'i hate',
      'i prefer',
      'i like',
      'prefer',
      'remember',
      'please',
    ];

    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }

    text = text
        .replaceAll(RegExp(r'\b(again|anymore|next time|later|course|courses|class|classes)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length > 80) {
      text = text.substring(0, 80).trim();
    }

    return text;
  }
}
