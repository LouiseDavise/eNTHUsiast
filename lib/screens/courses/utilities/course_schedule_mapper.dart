import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';

class CourseScheduleMapper {
  static const Map<String, int> _dayMap = {
    'M': 1,
    'T': 2,
    'W': 3,
    'R': 4,
    'F': 5,
  };

  static const Map<int, String> _dayNameMap = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
  };

  static const Map<String, int> _periodIndexMap = {
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

  static const List<_PeriodTime> _periods = [
    _PeriodTime(label: '1', start: '08:00', end: '08:50'),
    _PeriodTime(label: '2', start: '09:00', end: '09:50'),
    _PeriodTime(label: '3', start: '10:10', end: '11:00'),
    _PeriodTime(label: '4', start: '11:10', end: '12:00'),
    _PeriodTime(label: 'n', start: '12:10', end: '13:00'),
    _PeriodTime(label: '5', start: '13:20', end: '14:10'),
    _PeriodTime(label: '6', start: '14:20', end: '15:10'),
    _PeriodTime(label: '7', start: '15:30', end: '16:20'),
    _PeriodTime(label: '8', start: '16:30', end: '17:20'),
    _PeriodTime(label: '9', start: '17:30', end: '18:20'),
    _PeriodTime(label: 'a', start: '18:30', end: '19:20'),
    _PeriodTime(label: 'b', start: '19:30', end: '20:20'),
    _PeriodTime(label: 'c', start: '20:30', end: '21:20'),
    _PeriodTime(label: 'd', start: '21:30', end: '22:20'),
  ];

  static const List<_CoursePalette> _palettes = [
    _CoursePalette(
      bg: Color(0xFFEFF6FF),
      border: Color(0xFFBFDBFE),
      text: Color(0xFF1D4ED8),
    ),
    _CoursePalette(
      bg: Color(0xFFF0FDF4),
      border: Color(0xFFBBF7D0),
      text: Color(0xFF15803D),
    ),
    _CoursePalette(
      bg: Color(0xFFFFF7ED),
      border: Color(0xFFFED7AA),
      text: Color(0xFFC2410C),
    ),
    _CoursePalette(
      bg: Color(0xFFFAF5FF),
      border: Color(0xFFE9D5FF),
      text: Color(0xFF7E22CE),
    ),
    _CoursePalette(
      bg: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      text: Color(0xFFBE123C),
    ),
    _CoursePalette(
      bg: Color(0xFFF8FAFC),
      border: Color(0xFFCBD5E1),
      text: Color(0xFF475569),
    ),
  ];

  static List<CourseItem> fromCourseCatalog({
    required Map<String, dynamic> courseData,
    required String fallbackCode,
    required String fallbackTitle,
    required int colorIndex,
    String? overrideCourseType,
  }) {
    final String code = _clean(courseData['courseNo']) ?? fallbackCode;
    final String? titleZh = _clean(courseData['titleZh']);
    final String? titleEn = _clean(courseData['titleEn']);
    final String title = titleEn ?? titleZh ?? fallbackTitle;

    final String? baseLocation = _clean(courseData['location']);
    final String? rawTimeLocation = _clean(courseData['rawTimeLocation']);
    final String? teacher = _clean(courseData['teacher']);

    final String? slotCode = _combineSlotCodes([
      _clean(courseData['slotCode']),
      rawTimeLocation,
      baseLocation,
    ]);

    if (slotCode == null) {
      return [];
    }

    final int? credits = _toInt(courseData['credits']);
    final int? capacity = _toInt(courseData['capacity']);

    final String? departmentCode = _clean(courseData['departmentCode']);
    final String? departmentFullName = _clean(courseData['departmentFullName']);
    final String? language = _clean(courseData['language']);
    final String? requiredElectiveNote =
        _clean(courseData['requiredElectiveNote']);

    final String courseType = overrideCourseType ??
        _inferCourseType(
          code: code,
          credits: credits,
          departmentCode: departmentCode,
          requiredElectiveNote: requiredElectiveNote,
          geTarget: _clean(courseData['geTarget']),
          geCategory: _clean(courseData['geCategory']),
          courseAttribute: _clean(courseData['courseAttribute']),
        );

    final List<_SlotRun> runs = _parseSlotCode(slotCode);
    final _CoursePalette palette = _palettes[colorIndex % _palettes.length];

    return runs.map((run) {
      final String? blockLocation = _locationForRun(
        run: run,
        rawTimeLocation: rawTimeLocation,
        baseLocation: baseLocation,
      );

      return CourseItem(
        day: run.day,
        startSlot: run.startSlot,
        duration: run.duration,
        title: title,
        code: code,
        titleZh: titleZh,
        titleEn: titleEn,
        location: blockLocation,
        teacher: teacher,
        slotCode: slotCode,
        timeText: _timeRange(run.startSlot, run.duration),
        dayLabel: _dayNameMap[run.day],
        credits: credits,
        capacity: capacity,
        departmentCode: departmentCode,
        departmentFullName: departmentFullName,
        language: language,
        requiredElectiveNote: requiredElectiveNote,
        courseType: courseType,
        bg: palette.bg,
        border: palette.border,
        text: palette.text,
      );
    }).toList();
  }


  static String? _combineSlotCodes(List<String?> values) {
    final List<String> result = [];

    for (final value in values) {
      if (value == null || value.trim().isEmpty) continue;

      final List<String> foundCodes = _extractAllSlotCodes(value);

      for (final code in foundCodes) {
        final bool alreadyExists = result.any(
          (existing) => existing.toUpperCase() == code.toUpperCase(),
        );

        if (!alreadyExists) {
          result.add(code);
        }
      }
    }

    if (result.isEmpty) return null;

    return result.join('');
  }
  static String? _locationForRun({
    required _SlotRun run,
    required String? rawTimeLocation,
    required String? baseLocation,
  }) {
    final List<String> sources = [
      if (rawTimeLocation != null) rawTimeLocation,
      if (baseLocation != null) baseLocation,
    ];

    for (final source in sources) {
      final List<String> segments = source
          .split(RegExp(r'\s*/\s*'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      for (final segment in segments) {
        final List<String> segmentSlotCodes = _extractAllSlotCodes(segment);

        for (final segmentSlotCode in segmentSlotCodes) {
          final List<_SlotRun> segmentRuns = _parseSlotCode(segmentSlotCode);

          final bool matches = segmentRuns.any(
            (segmentRun) => _runsOverlap(run, segmentRun),
          );

          if (matches) {
            final String cleanedLocation = _removeSlotCodes(segment);
            if (cleanedLocation.isNotEmpty) {
              return cleanedLocation;
            }
          }
        }
      }
    }

    if (baseLocation == null) return null;

    final String cleanedFallback = _removeSlotCodes(baseLocation);
    return cleanedFallback.isEmpty ? baseLocation : cleanedFallback;
  }

  static bool _runsOverlap(_SlotRun a, _SlotRun b) {
    if (a.day != b.day) return false;

    final int aStart = a.startSlot;
    final int aEnd = a.startSlot + a.duration - 1;
    final int bStart = b.startSlot;
    final int bEnd = b.startSlot + b.duration - 1;

    return aStart <= bEnd && bStart <= aEnd;
  }

  static List<String> _extractAllSlotCodes(String text) {
    final RegExp pattern = RegExp(
      r'[MTWRF][1234n56789abcd](?:[MTWRF]?[1234n56789abcd])*',
      caseSensitive: false,
    );

    final List<String> result = [];

    for (final Match match in pattern.allMatches(text)) {
      final String? code = match.group(0);
      if (code == null) continue;

      final String before = match.start > 0 ? text[match.start - 1] : '';
      final String after = match.end < text.length ? text[match.end] : '';

      if (_isAsciiLetter(before) || _isAsciiLetter(after)) {
        continue;
      }

      result.add(code);
    }

    return result;
  }

  static bool _isAsciiLetter(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'[A-Za-z]').hasMatch(value);
  }

  static String _removeSlotCodes(String text) {
    String result = text;

    for (final String code in _extractAllSlotCodes(text)) {
      result = result.replaceAll(code, '');
    }

    return result
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*/\s*'), ' / ')
        .trim();
  }

  static String _timeRange(int startSlot, int duration) {
    if (startSlot < 0 || startSlot >= _periods.length) {
      return 'N/A';
    }

    final int endIndex = (startSlot + duration - 1).clamp(0, _periods.length - 1);
    return '${_periods[startSlot].start} - ${_periods[endIndex].end}';
  }

  static String _inferCourseType({
    required String code,
    required int? credits,
    required String? departmentCode,
    required String? requiredElectiveNote,
    required String? geTarget,
    required String? geCategory,
    required String? courseAttribute,
  }) {
    final String upperCode = code.toUpperCase();
    final String dep = (departmentCode ?? '').toUpperCase();
    final String note = (requiredElectiveNote ?? '').toLowerCase();
    final String attr = (courseAttribute ?? '').toLowerCase();

    if (upperCode.contains('PE') || dep == 'PE' || dep.contains('PE')) {
      return 'PE';
    }

    if (dep.contains('LANG') || dep == 'CL') {
      return 'LANGUAGE';
    }

    if ((geTarget ?? '').trim().isNotEmpty ||
        (geCategory ?? '').trim().isNotEmpty) {
      return 'GE';
    }

    if (note.contains('??') ||
        note.contains('required') ||
        attr.contains('core')) {
      return 'CORE';
    }

    if (note.contains('??') ||
        note.contains('elective') ||
        attr.contains('elective')) {
      return 'ELECTIVE';
    }

    if (credits == 0) {
      return 'PE';
    }

    return 'ELECTIVE';
  }

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _toInt(dynamic value) {
    final String? text = _clean(value);
    if (text == null) return null;
    return int.tryParse(text);
  }


  static List<_SlotRun> _parseSlotCode(String slotCode) {
    final Map<int, List<int>> slotsByDay = {};

    final RegExp tokenPattern = RegExp(
      r'([MTWRF])([1234n56789abcd])',
      caseSensitive: false,
    );

    for (final Match match in tokenPattern.allMatches(slotCode)) {
      final String dayLetter = match.group(1)!.toUpperCase();
      final String periodLabel = match.group(2)!.toLowerCase();

      final int? day = _dayMap[dayLetter];
      final int? periodIndex = _periodIndexMap[periodLabel];

      if (day == null || periodIndex == null) continue;

      slotsByDay.putIfAbsent(day, () => []);
      slotsByDay[day]!.add(periodIndex);
    }

    final List<_SlotRun> runs = [];

    for (final entry in slotsByDay.entries) {
      final List<int> sorted = entry.value.toSet().toList()..sort();
      if (sorted.isEmpty) continue;

      int start = sorted.first;
      int previous = sorted.first;

      for (int i = 1; i < sorted.length; i++) {
        final int current = sorted[i];

        if (current == previous + 1) {
          previous = current;
          continue;
        }

        runs.add(
          _SlotRun(
            day: entry.key,
            startSlot: start,
            duration: previous - start + 1,
          ),
        );

        start = current;
        previous = current;
      }

      runs.add(
        _SlotRun(
          day: entry.key,
          startSlot: start,
          duration: previous - start + 1,
        ),
      );
    }

    return runs;
  }
}

class _SlotRun {
  final int day;
  final int startSlot;
  final int duration;

  const _SlotRun({
    required this.day,
    required this.startSlot,
    required this.duration,
  });
}

class _CoursePalette {
  final Color bg;
  final Color border;
  final Color text;

  const _CoursePalette({
    required this.bg,
    required this.border,
    required this.text,
  });
}

class _PeriodTime {
  final String label;
  final String start;
  final String end;

  const _PeriodTime({
    required this.label,
    required this.start,
    required this.end,
  });
}



