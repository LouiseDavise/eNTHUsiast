import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/courses_model.dart';
import './utilities/course_schedule_mapper.dart';
import './widgets/timetable_grid.dart';
import './widgets/menu_square_button.dart';
import './widgets/menu_wide_button.dart';
import './courses_material_screen.dart';
import './graduation_verification_screen.dart';
import './courses_planner_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<_CurrentScheduleResult> _fetchCurrentSchedule() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _CurrentScheduleResult(
        semesterLabel: 'Current Semester',
        courses: [],
        message: 'Please log in to view your schedule.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>>? ccxpDoc =
        await _findCcxpUserDocument(user.uid);

    if (ccxpDoc == null || !ccxpDoc.exists) {
      return const _CurrentScheduleResult(
        semesterLabel: 'Current Semester',
        courses: [],
        message: 'No CCXP course data found for this account.',
      );
    }

    final Map<String, dynamic> userData = ccxpDoc.data() ?? {};
    final Map<String, String> courseTypeOverrides =
        _buildCourseTypeOverrides(userData);

    final List<dynamic> rawSchedule =
        (userData['scheduleData'] as List<dynamic>?) ?? [];

    if (rawSchedule.isEmpty) {
      return const _CurrentScheduleResult(
        semesterLabel: 'Current Semester',
        courses: [],
        message: 'No current semester courses found.',
      );
    }

    final List<_ScheduleCourseRef> courseRefs = rawSchedule
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final String code = _clean(item['code']) ?? '';
          final String title = _clean(item['title']) ?? 'Untitled Course';
          final String yearTerm = _yearTermFromCourseCode(code);

          return _ScheduleCourseRef(
            code: code,
            title: title,
            yearTerm: yearTerm,
            courseTypeOverride: courseTypeOverrides[_typeKey(title, yearTerm)],
          );
        })
        .where((item) => item.code.isNotEmpty)
        .toList();

    if (courseRefs.isEmpty) {
      return const _CurrentScheduleResult(
        semesterLabel: 'Current Semester',
        courses: [],
        message: 'No valid course codes found.',
      );
    }

    final String semester = _semesterFromCourseCode(courseRefs.first.code);
    final List<CourseItem> courses = [];

    for (int i = 0; i < courseRefs.length; i++) {
      final _ScheduleCourseRef courseRef = courseRefs[i];
      final Map<String, dynamic>? catalogData =
          await _findCourseCatalogData(courseRef.code);

      if (catalogData == null) {
        continue;
      }

      final String? catalogTitleEn = _clean(catalogData['titleEn']);
      final String? catalogTitleZh = _clean(catalogData['titleZh']);

      final String? catalogTypeOverride =
          courseTypeOverrides[_typeKey(catalogTitleEn ?? '', courseRef.yearTerm)] ??
              courseTypeOverrides[_typeKey(catalogTitleZh ?? '', courseRef.yearTerm)];

      courses.addAll(
        CourseScheduleMapper.fromCourseCatalog(
          courseData: catalogData,
          fallbackCode: courseRef.code,
          fallbackTitle: courseRef.title,
          colorIndex: i,
          overrideCourseType:
              courseRef.courseTypeOverride ?? catalogTypeOverride,
        ),
      );
    }

    return _CurrentScheduleResult(
      semesterLabel: semester,
      courses: courses,
      message: courses.isEmpty
          ? 'Your courses were found, but no valid timetable slots were available.'
          : null,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findCcxpUserDocument(
    String uid,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> byUid =
        await _db.collection('ccxpUsers').doc(uid).get();

    if (byUid.exists) {
      return byUid;
    }

    final QuerySnapshot<Map<String, dynamic>> byAuthUid = await _db
        .collection('ccxpUsers')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (byAuthUid.docs.isNotEmpty) {
      return byAuthUid.docs.first;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _findCourseCatalogData(String rawCode) async {
    final String semester = _semesterFromCourseCode(rawCode);
    final CollectionReference<Map<String, dynamic>> coursesRef = _db
        .collection('courseCatalogs')
        .doc(semester)
        .collection('courses');

    for (final String docId in _candidateDocIds(rawCode)) {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await coursesRef.doc(docId).get();

      if (doc.exists) {
        return doc.data();
      }
    }

    final QuerySnapshot<Map<String, dynamic>> byCourseNo = await coursesRef
        .where('courseNo', isEqualTo: rawCode.trim())
        .limit(1)
        .get();

    if (byCourseNo.docs.isNotEmpty) {
      return byCourseNo.docs.first.data();
    }

    final String normalizedCode = _normalizeCourseCode(rawCode);

    final QuerySnapshot<Map<String, dynamic>> byNormalized = await coursesRef
        .where('normalizedCourseNo', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (byNormalized.docs.isNotEmpty) {
      return byNormalized.docs.first.data();
    }

    return null;
  }

  Map<String, String> _buildCourseTypeOverrides(Map<String, dynamic> userData) {
    final Map<String, String> result = {};

    final dynamic graduationData = userData['graduationData'];
    if (graduationData is! Map) return result;

    final dynamic rawCategories = graduationData['categories'];
    if (rawCategories is! List) return result;

    for (final dynamic rawCategory in rawCategories) {
      if (rawCategory is! Map) continue;

      final Map<String, dynamic> category =
          Map<String, dynamic>.from(rawCategory);

      final String categoryTitle = _clean(category['title']) ?? '';
      final String? courseType = _courseTypeFromCategoryTitle(categoryTitle);

      if (courseType == null) continue;

      final dynamic rawRecords = category['records'];
      if (rawRecords is! List) continue;

      for (final dynamic rawRecord in rawRecords) {
        if (rawRecord is! Map) continue;

        final Map<String, dynamic> record =
            Map<String, dynamic>.from(rawRecord);

        final String title = _clean(record['title']) ?? '';
        final String year = _clean(record['year']) ?? '';

        if (title.isEmpty || year.isEmpty) continue;

        result[_typeKey(title, year)] = courseType;
      }
    }

    return result;
  }

  String? _courseTypeFromCategoryTitle(String title) {
    final String lower = title.toLowerCase();

    if (lower.contains('compulsory') ||
        lower.contains('required') ||
        title.contains('??')) {
      return 'CORE';
    }

    if (lower.contains('general education') ||
        lower.contains('ge') ||
        title.contains('??')) {
      return 'GE';
    }

    if (lower.contains('pe') ||
        lower.contains('service') ||
        title.contains('??') ||
        title.contains('??')) {
      return 'PE';
    }

    if (lower.contains('elective') || title.contains('??')) {
      return 'ELECTIVE';
    }

    return null;
  }

  String _typeKey(String title, String yearTerm) {
    return '${_normalizeText(title)}|${yearTerm.trim()}';
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _candidateDocIds(String rawCode) {
    final String trimmed = rawCode.trim();
    final String noSpaces = trimmed.replaceAll(RegExp(r'\s+'), '');
    final String underscore = trimmed.replaceAll(RegExp(r'\s+'), '_');

    return <String>{
      trimmed,
      underscore,
      noSpaces,
    }.where((value) => value.isNotEmpty).toList();
  }

  String _normalizeCourseCode(String rawCode) {
    return rawCode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _yearTermFromCourseCode(String rawCode) {
    final RegExp pattern = RegExp(r'^(\d{5})');
    final Match? match = pattern.firstMatch(rawCode.trim());

    if (match == null) {
      return '';
    }

    return match.group(1)!;
  }

  String _semesterFromCourseCode(String rawCode) {
    final RegExp pattern = RegExp(r'^(\d{3})(\d)0');
    final Match? match = pattern.firstMatch(rawCode.trim());

    if (match == null) {
      return '114-2';
    }

    final String year = match.group(1)!;
    final String term = match.group(2)!;

    return '$year-$term';
  }

  String? _clean(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: FutureBuilder<_CurrentScheduleResult>(
          future: _fetchCurrentSchedule(),
          builder: (context, snapshot) {
            final String semesterLabel =
                snapshot.data?.semesterLabel ?? 'Current Semester';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          semesterLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'My current semester timetable',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: _buildTimetableState(snapshot),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: MenuSquareButton(
                          title: 'Course\nMaterials',
                          icon: Icons.menu_book_rounded,
                          activeColor: const Color(0xFF7E22CE),
                          inactiveBgColor: const Color(0xFFF3E8FF),
                          inactiveIconColor: const Color(0xFF9333EA),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CourseMaterialsScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: MenuSquareButton(
                          title: 'Course\nPlanner',
                          icon: Icons.search_rounded,
                          activeColor: const Color(0xFF3B82F6),
                          inactiveBgColor: const Color(0xFFEFF6FF),
                          inactiveIconColor: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CoursePlannerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  MenuWideButton(
                    title: 'Graduation Verification',
                    subtitle: 'CHECK YOUR DEGREE PROGRESS',
                    icon: Icons.school_outlined,
                    activeColor: const Color(0xFFF97316),
                    inactiveBgColor: const Color(0xFFFFF7ED),
                    inactiveIconColor: const Color(0xFFF97316),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GraduationVerificationScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimetableState(
    AsyncSnapshot<_CurrentScheduleResult> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Text(
            'Error: ${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final _CurrentScheduleResult? result = snapshot.data;

    if (result == null || result.courses.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Text(
            result?.message ?? 'No courses found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return TimetableGrid(schedule: result.courses);
  }
}

class _CurrentScheduleResult {
  final String semesterLabel;
  final List<CourseItem> courses;
  final String? message;

  const _CurrentScheduleResult({
    required this.semesterLabel,
    required this.courses,
    this.message,
  });
}

class _ScheduleCourseRef {
  final String code;
  final String title;
  final String yearTerm;
  final String? courseTypeOverride;

  const _ScheduleCourseRef({
    required this.code,
    required this.title,
    required this.yearTerm,
    this.courseTypeOverride,
  });
}
