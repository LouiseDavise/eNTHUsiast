import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class CoursePlannerFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<PlannerCourse>> fetchCourses() async {
    final snapshot = await _firestore.collection('courses').get();

    final courses = snapshot.docs.map((doc) {
      final data = doc.data();

      return _courseFromFirestore(
        docId: doc.id,
        data: data,
      );
    }).toList();

    courses.sort((a, b) => a.code.compareTo(b.code));

    return courses;
  }

  PlannerCourse _courseFromFirestore({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final courseNo = _firstString(data, [
      'courseNo',
      'courseNumber',
      'code',
      '課號',
    ]);

    final code = courseNo.isNotEmpty ? courseNo : docId.replaceAll('_', ' ');

    final titleEn = _firstString(data, [
      'titleEn',
      'courseEnglishName',
      'courseNameEn',
      'englishName',
      '課程英文名稱',
    ]);

    final titleZh = _firstString(data, [
      'titleZh',
      'courseChineseName',
      'courseNameZh',
      'chineseName',
      '課程中文名稱',
    ]);

    final professor = _firstString(data, [
      'professor',
      'instructor',
      'teacher',
      '授課教師',
    ]);

    final rawSchedule = _firstString(data, [
      'classroomAndClassTime',
      'classTime',
      'timeSlot',
      'slotCode',
      '教室上課時間',
    ]);

    final location = _firstNonEmpty([
      _firstString(data, [
        'location',
        'classroom',
        '教室',
      ]),
      _parseLocationFromSchedule(rawSchedule),
    ]);

    final slotCode = _firstNonEmpty([
      _firstString(data, [
        'slotCode',
        'timeSlot',
      ]),
      _parseSlotCodeFromSchedule(rawSchedule),
    ]);

    final department = _firstNonEmpty([
      _firstString(data, [
        'departmentCode',
        'department',
        'deptCode',
      ]),
      _departmentFromCourseNo(code),
    ]).toUpperCase();

    final courseType = _parseCourseType(data, code);

    return PlannerCourse(
      id: docId,
      code: code,
      title: titleEn.isNotEmpty ? titleEn : titleZh,
      professor: professor,
      credits: _firstInt(data, [
        'credits',
        'credit',
        '學分',
      ]),
      type: courseType,
      department: department,
      slotCode: slotCode,
      timeSlot: slotCode,
      location: location,
      language: _firstString(data, [
        'language',
        'instructionLanguage',
        'languageOfInstruction',
        '授課語言',
      ]),
      rating: _firstDouble(data, [
        'rating',
      ]),
      reviews: _firstInt(data, [
        'reviews',
      ]),
      limit: _firstInt(data, [
        'limit',
        'enrollmentLimit',
        'capacity',
        '人限',
      ]),
      day: _parseDay(slotCode),
      startSlot: _parseStartSlot(slotCode),
      duration: _parseDuration(slotCode),
      midtermDate: 'TBA',
      finalDate: 'TBA',
      projectDate: 'TBA',
      grading: const {},
      syllabus: const [
        'Course information is loaded from Firebase.',
      ],
      color: _courseColor(courseType),
    );
  }

  String _parseCourseType(Map<String, dynamic> data, String courseNo) {
    final existingType = _firstString(data, [
      'type',
      'courseType',
    ]).toUpperCase();

    final upperCourseNo = courseNo.replaceAll(' ', '').toUpperCase();

    final geCategory = _firstString(data, [
      'geCategory',
      'generalEducationCategory',
      'General Education Category',
      '通識類別',
    ]);

    final geTarget = _firstString(data, [
      'geTarget',
      'generalEducationTarget',
      'General Education Target Audience',
      '通識對象',
    ]);

    // 1. GE first, because GE text may contain "Core GE courses".
    if (existingType == 'GE' ||
        upperCourseNo.contains('GE') ||
        geCategory.trim().isNotEmpty ||
        geTarget.trim().isNotEmpty) {
      return 'GE';
    }

    final requiredText = _firstString(data, [
      'requiredElectiveDescription',
      'requiredElectiveNote',
      'requiredOrElective',
      'requiredElective',
      'requiredElectiveCourseDescription',
      'requiredElectiveCourse',
      'Required/Elective Course Description',
      'Required Elective Course Description',
      'Required/Elective',
      '必選修說明',
      '必修/選修',
      '必選修',
    ]);

    final lowerRequiredText = requiredText.toLowerCase();

    // 2. CORE before trusting existing ELECTIVE.
    if (existingType == 'CORE' ||
        requiredText.contains('必修') ||
        requiredText.contains('校定必修') ||
        requiredText.contains('院定必修') ||
        requiredText.contains('系定必修') ||
        lowerRequiredText.contains('required') ||
        lowerRequiredText.contains('compulsory') ||
        lowerRequiredText.contains('core')) {
      return 'CORE';
    }

    // 3. ELECTIVE last.
    if (existingType == 'ELECTIVE' ||
        requiredText.contains('選修') ||
        lowerRequiredText.contains('elective')) {
      return 'ELECTIVE';
    }

    return 'ELECTIVE';
  }
  Map<String, int> _parseGrading(Map<String, dynamic> data) {
    final raw = data['grading'];

    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          _intValue(value),
        ),
      );
    }

    return {
      'Exams': 40,
      'Projects': 40,
      'Participation': 20,
    };
  }

  Color _courseColor(String type) {
    switch (type.toUpperCase()) {
      case 'CORE':
        return const Color(0xFFFF2D55);
      case 'GE':
        return const Color(0xFFFF6B2C);
      case 'ELECTIVE':
        return const Color(0xFF7E3291);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _departmentFromCourseNo(String courseNo) {
    final compact = courseNo.replaceAll(' ', '').toUpperCase();
    final match = RegExp(r'^[0-9]+([A-Z]+)').firstMatch(compact);

    if (match == null) {
      return 'UNKNOWN';
    }

    return match.group(1) ?? 'UNKNOWN';
  }

  String _parseLocationFromSchedule(String raw) {
    if (raw.trim().isEmpty) return '';

    final slotMatch = RegExp(
      r'[MTWRFSU][1-9ABCDN]',
      caseSensitive: false,
    ).firstMatch(raw);

    if (slotMatch == null) {
      return raw.trim();
    }

    return raw.substring(0, slotMatch.start).trim();
  }

  String _parseSlotCodeFromSchedule(String raw) {
    if (raw.trim().isEmpty) return '';

    final matches = RegExp(
      r'[MTWRFSU][1-9ABCDN]',
      caseSensitive: false,
    )
        .allMatches(raw)
        .map((match) => match.group(0) ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    return matches.join('').toUpperCase();
  }

  int _parseDay(String slotCode) {
    if (slotCode.trim().isEmpty) return 0;

    final firstDay = slotCode.trim().toUpperCase()[0];

    switch (firstDay) {
      case 'M':
        return 1;
      case 'T':
        return 2;
      case 'W':
        return 3;
      case 'R':
        return 4;
      case 'F':
        return 5;
      case 'S':
        return 6;
      case 'U':
        return 7;
      default:
        return 0;
    }
  }

  int _parseStartSlot(String slotCode) {
    final firstSlot = RegExp(
      r'[MTWRFSU]([1-9ABCDN])',
      caseSensitive: false,
    ).firstMatch(slotCode);

    if (firstSlot == null) return 0;

    return _slotValue(firstSlot.group(1) ?? '');
  }

  int _parseDuration(String slotCode) {
    final firstDayMatch = RegExp(
      r'([MTWRFSU])[1-9ABCDN]',
      caseSensitive: false,
    ).firstMatch(slotCode);

    if (firstDayMatch == null) return 1;

    final firstDay = firstDayMatch.group(1)?.toUpperCase();

    final sameDaySlots = RegExp(
      r'([MTWRFSU])([1-9ABCDN])',
      caseSensitive: false,
    )
        .allMatches(slotCode)
        .where((match) => match.group(1)?.toUpperCase() == firstDay)
        .length;

    if (sameDaySlots <= 0) return 1;

    return sameDaySlots;
  }

  int _slotValue(String rawSlot) {
    final slot = rawSlot.toUpperCase();

    switch (slot) {
      case 'N':
        return 5;
      case 'A':
        return 10;
      case 'B':
        return 11;
      case 'C':
        return 12;
      case 'D':
        return 13;
      default:
        return int.tryParse(slot) ?? 0;
    }
  }

  String _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  int _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _intValue(value);

      if (parsed != 0) {
        return parsed;
      }
    }

    return 0;
  }

  int _intValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    final raw = value.toString().trim();
    final match = RegExp(r'\d+').firstMatch(raw);

    if (match == null) return 0;

    return int.tryParse(match.group(0) ?? '') ?? 0;
  }

  double _firstDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _doubleValue(value);

      if (parsed != 0.0) {
        return parsed;
      }
    }

    return 0.0;
  }

  double _doubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0.0;
  }
}