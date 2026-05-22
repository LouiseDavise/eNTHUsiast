import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class CoursePlannerFirestoreService {
  final CollectionReference<Map<String, dynamic>> _coursesRef =
      FirebaseFirestore.instance.collection('courses');

  Future<List<PlannerCourse>> fetchCourses() async {
    final snapshot = await _coursesRef.orderBy('courseNo').get();

    return snapshot.docs.map(_mapDocToPlannerCourse).toList();
  }

  PlannerCourse _mapDocToPlannerCourse(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final courseNo = _stringValue(
      data['courseNo'] ??
          data['Course Number'] ??
          data['科號'],
      fallback: doc.id,
    );

    final titleZh = _stringValue(
      data['titleZh'] ??
          data['Course Chinese Name'] ??
          data['課程中文名稱'],
    );

    final titleEn = _stringValue(
      data['titleEn'] ??
          data['Course English Name'] ??
          data['課程英文名稱'],
    );

    final credits = _intValue(
      data['credits'] ??
          data['Credits'] ??
          data['學分數'],
    );

    final enrollmentLimit = _nullableIntValue(
      data['enrollmentLimit'] ??
          data['capacity'] ??
          data['Enrollment Limit'] ??
          data['人限'],
    );

    final teacher = _stringValue(
      data['teacher'] ??
          data['instructor'] ??
          data['Instructor'] ??
          data['授課教師'],
      fallback: 'TBA',
    );

    final rawTimeLocation = _stringValue(
      data['rawTimeLocation'] ??
          data['Classroom and Class Time'] ??
          data['教室與上課時間'],
    );

    final storedLocation = _stringValue(data['location']);
    final storedSlotCode = _stringValue(data['slotCode']);

    final parsedTimeLocation = _parseTimeLocation(rawTimeLocation);

    final location = storedLocation.isNotEmpty
        ? storedLocation
        : parsedTimeLocation.location;

    final slotCode = storedSlotCode.isNotEmpty
        ? storedSlotCode
        : parsedTimeLocation.slotCode;

    final departmentCode = _stringValue(
      data['departmentCode'],
      fallback: _extractDepartmentCode(courseNo),
    );

    final parsedSlot = _parseSlotCode(slotCode);

    return PlannerCourse(
      id: doc.id,
      code: courseNo,
      title: titleEn.isNotEmpty ? titleEn : titleZh,
      professor: teacher,
      credits: credits,
      type: _guessCourseType(data),
      department: departmentCode,
      limit: enrollmentLimit ?? -1,
      rating: 0.0,
      reviews: 0,
      midtermDate: 'TBA',
      finalDate: 'TBA',
      projectDate: 'TBA',
      grading: const {},
      syllabus: const [
        'Course information is loaded from Firebase.',
      ],

      // Show only the slot code in detail sheet, like R7R8R9.
      timeSlot: slotCode.isNotEmpty ? slotCode : 'TBA',

      slotCode: slotCode,
      location: location.isNotEmpty ? location : 'TBA',
      day: parsedSlot.day,
      startSlot: parsedSlot.startSlot,
      duration: parsedSlot.duration,
      color: _courseColor(doc.id),
    );
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  int _intValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is double) return value.round();

    if (value is num) return value.round();

    return int.tryParse(value.toString()) ?? 0;
  }

  int? _nullableIntValue(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.round();

    if (value is num) return value.round();

    final text = value.toString().trim();

    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  String _guessCourseType(Map<String, dynamic> data) {
    final requiredElectiveNote = _stringValue(
      data['requiredElectiveNote'] ??
          data['Required/Elective Course Description'] ??
          data['必選修說明'],
    );

    final geCategory = _stringValue(
      data['geCategory'] ??
          data['General Education Category'] ??
          data['通識類別'],
    );

    final title = _stringValue(
      data['titleEn'] ??
          data['Course English Name'] ??
          data['課程英文名稱'],
    ).toLowerCase();

    if (geCategory.isNotEmpty) {
      return 'GE';
    }

    if (title.contains('lab') || title.contains('laboratory')) {
      return 'LAB';
    }

    if (requiredElectiveNote.contains('必修')) {
      return 'CORE';
    }

    if (requiredElectiveNote.contains('選修')) {
      return 'ELECTIVE';
    }

    return 'ELECTIVE';
  }

  String _extractDepartmentCode(String courseNo) {
    final text = courseNo.trim();

    // Example:
    // 11420AES 470100 -> AES
    // 11420AIA 100100 -> AIA
    final match = RegExp(r'11420([A-Z]+)').firstMatch(text);

    if (match == null) {
      return 'NTHU';
    }

    return match.group(1) ?? 'NTHU';
  }

  _ParsedTimeLocation _parseTimeLocation(String raw) {
    if (raw.trim().isEmpty) {
      return const _ParsedTimeLocation(
        location: '',
        slotCode: '',
      );
    }

    final text = raw.trim();
    final parts = text.split(RegExp(r'\s+'));

    if (parts.length <= 1) {
      return _ParsedTimeLocation(
        location: text,
        slotCode: '',
      );
    }

    return _ParsedTimeLocation(
      location: parts.sublist(0, parts.length - 1).join(' '),
      slotCode: parts.last,
    );
  }

  _ParsedSlot _parseSlotCode(String slotCode) {
    if (slotCode.trim().isEmpty) {
      return const _ParsedSlot(
        day: 1,
        startSlot: 0,
        duration: 1,
      );
    }

    const dayMap = {
      'M': 1,
      'T': 2,
      'W': 3,
      'R': 4,
      'F': 5,
    };

    const periodMap = {
      '1': 0,
      '2': 1,
      '3': 2,
      '4': 3,
      'n': 4,
      '5': 5,
      '6': 6,
      '7': 7,
      '8': 8,
      '9': 9,
      'a': 10,
      'b': 11,
      'c': 12,
      'd': 13,
    };

    final matches = RegExp(r'([MTWRF])([1234n56789abcd])')
        .allMatches(slotCode)
        .toList();

    if (matches.isEmpty) {
      return const _ParsedSlot(
        day: 1,
        startSlot: 0,
        duration: 1,
      );
    }

    final firstDayCode = matches.first.group(1) ?? 'M';
    final firstDay = dayMap[firstDayCode] ?? 1;

    final sameDayPeriods = matches
        .where((match) => match.group(1) == firstDayCode)
        .map((match) {
          final periodCode = match.group(2) ?? '1';
          return periodMap[periodCode] ?? 0;
        })
        .toList()
      ..sort();

    if (sameDayPeriods.isEmpty) {
      return _ParsedSlot(
        day: firstDay,
        startSlot: 0,
        duration: 1,
      );
    }

    final startSlot = sameDayPeriods.first;
    final endSlot = sameDayPeriods.last;

    return _ParsedSlot(
      day: firstDay,
      startSlot: startSlot,
      duration: (endSlot - startSlot + 1).clamp(1, 14),
    );
  }

  Color _courseColor(String id) {
    const colors = [
      Color(0xFF60A5FA),
      Color(0xFFA855F7),
      Color(0xFF14B8A6),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
      Color(0xFF34D399),
      Color(0xFFFB7185),
      Color(0xFFF97316),
      Color(0xFF818CF8),
      Color(0xFF2DD4BF),
    ];

    final hash = id.codeUnits.fold<int>(
      0,
      (previousValue, element) => previousValue + element,
    );

    return colors[hash % colors.length];
  }
}

class _ParsedTimeLocation {
  final String location;
  final String slotCode;

  const _ParsedTimeLocation({
    required this.location,
    required this.slotCode,
  });
}

class _ParsedSlot {
  final int day;
  final int startSlot;
  final int duration;

  const _ParsedSlot({
    required this.day,
    required this.startSlot,
    required this.duration,
  });
}