import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:enthusiast/models/courses_model.dart';

class CourseScheduleMapper {
  CourseScheduleMapper._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> semesterOrder = [
    '113-1',
    '113-2',
    '114-1',
    '114-2',
  ];

  static const List<_PeriodInfo> _periods = [
    _PeriodInfo(label: '1', start: '08:00', end: '08:50'),
    _PeriodInfo(label: '2', start: '09:00', end: '09:50'),
    _PeriodInfo(label: '3', start: '10:10', end: '11:00'),
    _PeriodInfo(label: '4', start: '11:10', end: '12:00'),
    _PeriodInfo(label: 'n', start: '12:10', end: '13:00'),
    _PeriodInfo(label: '5', start: '13:20', end: '14:10'),
    _PeriodInfo(label: '6', start: '14:20', end: '15:10'),
    _PeriodInfo(label: '7', start: '15:30', end: '16:20'),
    _PeriodInfo(label: '8', start: '16:30', end: '17:20'),
    _PeriodInfo(label: '9', start: '17:30', end: '18:20'),
    _PeriodInfo(label: 'a', start: '18:30', end: '19:20'),
    _PeriodInfo(label: 'b', start: '19:30', end: '20:20'),
    _PeriodInfo(label: 'c', start: '20:30', end: '21:20'),
    _PeriodInfo(label: 'd', start: '21:30', end: '22:20'),
  ];

  static const List<_CoursePalette> _palettes = [
    _CoursePalette(bg: Color(0xFFFFC58F), border: Color(0xFFF4A261), text: Color(0xFF111827)),
    _CoursePalette(bg: Color(0xFFC8AA99), border: Color(0xFFA87F6D), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFF95BFC1), border: Color(0xFF6EA5A8), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFFC95B7A), border: Color(0xFFAF4564), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFF89C7B0), border: Color(0xFF62AA91), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFFC9C35A), border: Color(0xFFA8A23F), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFFB9ADD0), border: Color(0xFF9587B3), text: Color(0xFFFFFFFF)),
    _CoursePalette(bg: Color(0xFFD68A73), border: Color(0xFFBD6E57), text: Color(0xFFFFFFFF)),
  ];

  static Future<List<CourseItem>> buildSemesterSchedule({
    required String semester,
    dynamic fallbackScheduleData,
    String studentIdOverride = '',
  }) async {
    final userRef = await _resolveCcxpUserReference(studentIdOverride: studentIdOverride);

    if (userRef != null) {
      final semesterDoc = await userRef.collection('semesterCourses').doc(semester).get();
      final data = semesterDoc.data();
      final rows = _semesterCourseRows(data);

      if (rows.isNotEmpty) {
        final events = _eventsFromSemesterCourseRows(rows);
        events.sort((a, b) {
          final dayCompare = a.day.compareTo(b.day);
          if (dayCompare != 0) return dayCompare;
          return a.startSlot.compareTo(b.startSlot);
        });
        return events;
      }
    }

    final fallbackSemester = semesterFromSchedule(fallbackScheduleData);
    if (fallbackSemester == semester) {
      return buildCurrentSchedule(fallbackScheduleData);
    }

    return const [];
  }

  static Future<List<CourseItem>> buildCurrentSchedule(dynamic scheduleData) async {
    final userRows = _scheduleRows(scheduleData);
    if (userRows.isEmpty) return const [];

    // Use exact synced user schedule first.
    // This preserves multi-day slots like T3T4R4, T5T6F5F6, etc.
    final exactEvents = _eventsFromSemesterCourseRows(userRows);
    if (exactEvents.isNotEmpty) {
      exactEvents.sort((a, b) {
        final dayCompare = a.day.compareTo(b.day);
        if (dayCompare != 0) return dayCompare;
        return a.startSlot.compareTo(b.startSlot);
      });
      return exactEvents;
    }

    final userCodes = userRows
        .map(_courseCodeFromUserRow)
        .where((code) => code.trim().isNotEmpty)
        .toList();

    if (userCodes.isEmpty) return const [];

    final courseSnapshot = await _firestore.collection('courses').get();
    final courseMap = <String, _CourseRecord>{};

    for (final doc in courseSnapshot.docs) {
      final record = _CourseRecord.fromFirestore(doc.id, doc.data());
      final keys = <String>{
        _normalizeCourseCode(record.courseNo),
        _normalizeCourseCode(record.docId),
        _normalizeCourseCode(record.courseNo.replaceAll(' ', '_')),
      };

      for (final key in keys) {
        if (key.isEmpty) continue;
        courseMap[key] = record;
      }
    }

    final events = <CourseItem>[];

    for (var i = 0; i < userRows.length; i++) {
      final userRow = userRows[i];
      final userCode = _courseCodeFromUserRow(userRow);
      final normalizedUserCode = _normalizeCourseCode(userCode);
      if (normalizedUserCode.isEmpty) continue;

      final matchedCourse = courseMap[normalizedUserCode];

      if (matchedCourse != null) {
        events.addAll(_eventsFromCourse(matchedCourse, userRow, i));
        continue;
      }

      final fallbackEvent = _fallbackEventFromUserRow(userRow, i);
      if (fallbackEvent != null) {
        events.add(fallbackEvent);
      }
    }

    events.sort((a, b) {
      final dayCompare = a.day.compareTo(b.day);
      if (dayCompare != 0) return dayCompare;
      return a.startSlot.compareTo(b.startSlot);
    });

    return events;
  }

  static String semesterLabelFromSchedule(dynamic scheduleData) {
    final semester = semesterFromSchedule(scheduleData);
    if (semester.isEmpty) return 'Current Semester';
    return '$semester Semester';
  }

  static String semesterFromSchedule(dynamic scheduleData) {
    final rows = _scheduleRows(scheduleData);

    for (final row in rows) {
      final code = _normalizeCourseCode(_courseCodeFromUserRow(row));
      final match = RegExp(r'^(\d{3})(\d)').firstMatch(code);
      if (match == null) continue;

      final year = match.group(1);
      final semester = match.group(2);
      if (year == null || semester == null) continue;

      return '$year-$semester';
    }

    return '';
  }

  static Future<DocumentReference<Map<String, dynamic>>?> _resolveCcxpUserReference({
    required String studentIdOverride,
  }) async {
    final studentId = studentIdOverride.trim();

    if (studentId.isNotEmpty) {
      final byStudentId = await _queryCcxpUserByAnyStudentId(studentId);
      if (byStudentId != null) return byStudentId;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final uid = authUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;

    final directDoc = await _firestore.collection('ccxpUsers').doc(uid).get();
    if (directDoc.exists) return directDoc.reference;

    final byAuthUid = await _firestore
        .collection('ccxpUsers')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (byAuthUid.docs.isNotEmpty) return byAuthUid.docs.first.reference;

    final byUidInUsers = await _firestore.collection('users').doc(uid).get();
    final userData = byUidInUsers.data();
    final possibleStudentId = _firstString(userData ?? const {}, [
      'studentId',
      'accountStudentId',
      'ccountStudentId',
    ]);

    if (possibleStudentId.isNotEmpty) {
      final byStudent = await _queryCcxpUserByAnyStudentId(possibleStudentId);
      if (byStudent != null) return byStudent;
    }

    return null;
  }

  static Future<DocumentReference<Map<String, dynamic>>?> _queryCcxpUserByAnyStudentId(
    String studentId,
  ) async {
    final collection = _firestore.collection('ccxpUsers');
    final fields = [
      'studentId',
      'accountStudentId',
      'ccountStudentId',
      'studentInfo.studentId',
    ];

    for (final field in fields) {
      final query = await collection.where(field, isEqualTo: studentId).limit(1).get();
      if (query.docs.isNotEmpty) return query.docs.first.reference;
    }

    return null;
  }

  static List<Map<String, dynamic>> _semesterCourseRows(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final courses = data['courses'];
    if (courses is! List) return const [];

    return courses
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<CourseItem> _eventsFromSemesterCourseRows(List<Map<String, dynamic>> rows) {
    final events = <CourseItem>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final slotCode = _firstString(row, ['time', 'slotCode', 'timeSlot']).toUpperCase();
      if (slotCode.trim().isEmpty) continue;

      final blocks = _parseSlotBlocks(slotCode);
      if (blocks.isEmpty) continue;

      final code = _firstString(row, ['code', 'courseNo', 'courseNumber']);
      final title = _firstString(row, ['title', 'titleEn', 'courseName', 'name']);
      final room = _firstString(row, ['room', 'location', 'classroom']);
      final teacher = _firstString(row, ['teacher', 'professor', 'instructor']);
      final credits = _firstInt(row, ['credits', 'credit']);
      final palette = _paletteFor(code.isEmpty ? title : code, i);

      for (final block in blocks) {
        events.add(CourseItem(
          day: block.day,
          startSlot: block.startSlot,
          duration: block.duration,
          title: title.isEmpty ? (code.isEmpty ? 'Course' : code) : title,
          code: code,
          courseNo: code,
          room: room,
          timeRange: _timeRange(block.startSlot, block.duration),
          teacher: teacher,
          slotCode: slotCode,
          credits: credits,
          bg: palette.bg,
          border: palette.border,
          text: palette.text,
        ));
      }
    }

    return events;
  }

  static List<Map<String, dynamic>> _scheduleRows(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      for (final key in ['scheduleData', 'schedule', 'courses', 'records']) {
        final value = map[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }

    return const [];
  }

  static List<CourseItem> _eventsFromCourse(
    _CourseRecord course,
    Map<String, dynamic> userRow,
    int colorSeed,
  ) {
    final slotCode = course.slotCode.trim().isNotEmpty
        ? course.slotCode.trim()
        : _parseSlotCodeFromRaw(course.rawTimeLocation);

    final blocks = _parseSlotBlocks(slotCode);
    if (blocks.isEmpty) return const [];

    final palette = _paletteFor(course.courseNo, colorSeed);
    final userBg = _colorFromUserRow(userRow, 'bg');
    final userBorder = _colorFromUserRow(userRow, 'border');
    final userText = _colorFromUserRow(userRow, 'text');

    return blocks.map((block) {
      final timeRange = _timeRange(block.startSlot, block.duration);
      final title = course.titleEn.trim().isNotEmpty
          ? course.titleEn.trim()
          : course.titleZh.trim().isNotEmpty
              ? course.titleZh.trim()
              : _firstString(userRow, ['title', 'name', 'courseName']);

      return CourseItem(
        day: block.day,
        startSlot: block.startSlot,
        duration: block.duration,
        title: title.trim().isEmpty ? course.courseNo : title.trim(),
        code: course.location.trim().isEmpty ? course.courseNo : course.location.trim(),
        courseNo: course.courseNo,
        room: course.location,
        timeRange: timeRange,
        teacher: course.teacher,
        slotCode: slotCode,
        credits: course.credits,
        bg: userBg ?? palette.bg,
        border: userBorder ?? palette.border,
        text: userText ?? palette.text,
      );
    }).toList();
  }

  static CourseItem? _fallbackEventFromUserRow(
    Map<String, dynamic> row,
    int colorSeed,
  ) {
    final day = _intValue(row['day']);
    final startSlot = _intValue(row['startSlot']);
    final duration = _intValue(row['duration']);

    if (day < 1 || day > 5 || duration <= 0) return null;

    final palette = _paletteFor(_courseCodeFromUserRow(row), colorSeed);
    final title = _firstString(row, ['title', 'titleEn', 'name', 'courseName']);

    return CourseItem(
      day: day,
      startSlot: startSlot,
      duration: duration,
      title: title.isEmpty ? 'Course' : title,
      code: _courseCodeFromUserRow(row),
      courseNo: _courseCodeFromUserRow(row),
      timeRange: _timeRange(startSlot, duration),
      bg: _colorFromUserRow(row, 'bg') ?? palette.bg,
      border: _colorFromUserRow(row, 'border') ?? palette.border,
      text: _colorFromUserRow(row, 'text') ?? palette.text,
    );
  }

  static List<_SlotBlock> _parseSlotBlocks(String rawSlotCode) {
    final slotCode = rawSlotCode
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^MTWRF1-9ABCDN]'), '');

    if (slotCode.isEmpty) return const [];

    final matches = RegExp(r'([MTWRF])([1-9ABCDN])')
        .allMatches(slotCode)
        .map((match) => _ParsedSlot(
              dayLetter: match.group(1) ?? '',
              slotLabel: match.group(2) ?? '',
            ))
        .where((slot) => slot.dayLetter.isNotEmpty && slot.slotLabel.isNotEmpty)
        .toList();

    if (matches.isEmpty) return const [];

    final byDay = <String, List<int>>{};

    for (final slot in matches) {
      final index = _slotIndex(slot.slotLabel);
      if (index < 0) continue;
      byDay.putIfAbsent(slot.dayLetter, () => []).add(index);
    }

    final blocks = <_SlotBlock>[];

    for (final entry in byDay.entries) {
      final day = _dayIndex(entry.key);
      if (day == 0) continue;

      final slots = entry.value.toSet().toList()..sort();
      if (slots.isEmpty) continue;

      var blockStart = slots.first;
      var previous = slots.first;

      for (var i = 1; i < slots.length; i++) {
        final current = slots[i];

        if (current == previous + 1) {
          previous = current;
          continue;
        }

        blocks.add(_SlotBlock(
          day: day,
          startSlot: blockStart,
          duration: previous - blockStart + 1,
        ));

        blockStart = current;
        previous = current;
      }

      blocks.add(_SlotBlock(
        day: day,
        startSlot: blockStart,
        duration: previous - blockStart + 1,
      ));
    }

    return blocks;
  }
  static int _dayIndex(String dayLetter) {
    switch (dayLetter.toUpperCase()) {
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
      default:
        return 0;
    }
  }

  static int _slotIndex(String rawSlot) {
    switch (rawSlot.toUpperCase()) {
      case '1':
        return 0;
      case '2':
        return 1;
      case '3':
        return 2;
      case '4':
        return 3;
      case 'N':
        return 4;
      case '5':
        return 5;
      case '6':
        return 6;
      case '7':
        return 7;
      case '8':
        return 8;
      case '9':
        return 9;
      case 'A':
        return 10;
      case 'B':
        return 11;
      case 'C':
        return 12;
      case 'D':
        return 13;
      default:
        return -1;
    }
  }

  static String _timeRange(int startSlot, int duration) {
    if (startSlot < 0 || startSlot >= _periods.length) return '';

    final endSlot = (startSlot + duration - 1).clamp(0, _periods.length - 1);
    return '${_periods[startSlot].start} - ${_periods[endSlot].end}';
  }

  static String _parseSlotCodeFromRaw(String raw) {
    final slotCode = raw.trim().toUpperCase();
    final rawMatches = RegExp(r'[MTWRF][1-9ABCDN]').allMatches(slotCode);
    final matches = <String>[];

    for (final match in rawMatches) {
      final start = match.start;
      final end = match.end;
      final before = start > 0 ? slotCode[start - 1] : '';
      final after = end < slotCode.length ? slotCode[end] : '';
      final beforeIsAsciiLetter = RegExp(r'[A-Z]').hasMatch(before);
      final afterIsAsciiLetter = RegExp(r'[A-Z]').hasMatch(after);
      if (beforeIsAsciiLetter || afterIsAsciiLetter) continue;

      matches.add(match.group(0) ?? '');
    }

    return matches.join('').toUpperCase();
  }

  static String _parseLocationFromRaw(String raw) {
    final match = RegExp(r'[MTWRF][1-9ABCDN]', caseSensitive: false).firstMatch(raw);

    if (match == null) return raw.trim();
    return raw.substring(0, match.start).trim();
  }

  static _CoursePalette _paletteFor(String key, int fallbackIndex) {
    final normalizedKey = _normalizeCourseCode(key);
    final hash = normalizedKey.isEmpty ? fallbackIndex : normalizedKey.hashCode.abs();
    return _palettes[hash % _palettes.length];
  }

  static Color? _colorFromUserRow(Map<String, dynamic> row, String key) {
    final raw = row[key];
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (!text.startsWith('0x')) return null;

    final parsed = int.tryParse(text);
    if (parsed == null) return null;

    return Color(parsed);
  }

  static String _courseCodeFromUserRow(Map<String, dynamic> row) {
    return _firstString(row, [
      'courseNo',
      'courseNumber',
      'code',
      'courseCode',
      'èª²è™Ÿ',
    ]);
  }

  static String _normalizeCourseCode(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String _firstString(Map<String, dynamic> data, List<String> keys) {
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

  static int _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final parsed = _intValue(data[key]);
      if (parsed != 0) return parsed;
    }

    return 0;
  }

  static int _intValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    final match = RegExp(r'\d+').firstMatch(value.toString());
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }
}

class _CourseRecord {
  const _CourseRecord({
    required this.docId,
    required this.courseNo,
    required this.titleEn,
    required this.titleZh,
    required this.teacher,
    required this.location,
    required this.rawTimeLocation,
    required this.slotCode,
    required this.credits,
  });

  final String docId;
  final String courseNo;
  final String titleEn;
  final String titleZh;
  final String teacher;
  final String location;
  final String rawTimeLocation;
  final String slotCode;
  final int credits;

  factory _CourseRecord.fromFirestore(String docId, Map<String, dynamic> data) {
    final courseNo = CourseScheduleMapper._firstString(data, [
      'courseNo',
      'courseNumber',
      'code',
      'èª²è™Ÿ',
      'ç§‘è™Ÿ',
    ]);

    final rawTimeLocation = CourseScheduleMapper._firstString(data, [
      'rawTimeLocation',
      'classroomAndClassTime',
      'classTime',
      'timeSlot',
      'æ•™å®¤èˆ‡ä¸Šèª²æ™‚é–“',
      'æ•™å®¤ä¸Šèª²æ™‚é–“',
    ]);

    final location = CourseScheduleMapper._firstString(data, [
      'location',
      'classroom',
      'æ•™å®¤',
    ]);

    final slotCode = CourseScheduleMapper._firstString(data, [
      'slotCode',
      'timeSlot',
      'ä¸Šèª²æ™‚é–“',
    ]);

    return _CourseRecord(
      docId: docId,
      courseNo: courseNo.trim().isNotEmpty ? courseNo.trim() : docId.replaceAll('_', ' '),
      titleEn: CourseScheduleMapper._firstString(data, [
        'titleEn',
        'courseEnglishName',
        'courseNameEn',
        'englishName',
        'èª²ç¨‹è‹±æ–‡åç¨±',
        'è‹±æ–‡èª²å',
      ]),
      titleZh: CourseScheduleMapper._firstString(data, [
        'titleZh',
        'courseChineseName',
        'courseNameZh',
        'chineseName',
        'èª²ç¨‹ä¸­æ–‡åç¨±',
        'ä¸­æ–‡èª²å',
      ]),
      teacher: CourseScheduleMapper._firstString(data, [
        'teacher',
        'professor',
        'instructor',
        'æŽˆèª²æ•™å¸«',
        'æ•™å¸«',
      ]),
      location: location.trim().isNotEmpty
          ? location.trim()
          : CourseScheduleMapper._parseLocationFromRaw(rawTimeLocation),
      rawTimeLocation: rawTimeLocation,
      slotCode: slotCode.trim().isNotEmpty
          ? slotCode.trim().toUpperCase()
          : CourseScheduleMapper._parseSlotCodeFromRaw(rawTimeLocation),
      credits: CourseScheduleMapper._firstInt(data, [
        'credits',
        'credit',
        'å­¸åˆ†',
        'å­¸åˆ†æ•¸',
      ]),
    );
  }
}

class _PeriodInfo {
  const _PeriodInfo({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final String start;
  final String end;
}

class _CoursePalette {
  const _CoursePalette({
    required this.bg,
    required this.border,
    required this.text,
  });

  final Color bg;
  final Color border;
  final Color text;
}

class _ParsedSlot {
  const _ParsedSlot({required this.dayLetter, required this.slotLabel});

  final String dayLetter;
  final String slotLabel;
}

class _SlotBlock {
  const _SlotBlock({
    required this.day,
    required this.startSlot,
    required this.duration,
  });

  final int day;
  final int startSlot;
  final int duration;
}


