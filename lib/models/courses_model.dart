import 'package:flutter/material.dart';

class CourseItem {
  final int day; // 1 = Mon ... 5 = Fri
  final int startSlot; // 0-based index into timetable periods
  final int duration; // number of slots spanned

  final String title;
  final String code;

  final Color bg;
  final Color border;
  final Color text;

  final String room;
  final String timeRange;
  final String teacher;
  final String slotCode;
  final String courseNo;
  final int credits;

  // Compatibility fields used by timetable/detail widgets.
  final String? location;
  final String? timeText;
  final String? dayLabel;
  final String? courseType;
  final String? departmentFullName;
  final String? departmentCode;
  final String? requiredElectiveNote;
  final int? capacity;
  final String? language;

  const CourseItem({
    required this.day,
    required this.startSlot,
    required this.duration,
    required this.title,
    required this.code,
    required this.bg,
    required this.border,
    required this.text,
    this.room = '',
    this.timeRange = '',
    this.teacher = '',
    this.slotCode = '',
    this.courseNo = '',
    this.credits = 0,
    String? location,
    String? timeText,
    this.dayLabel,
    this.courseType,
    this.departmentFullName,
    this.departmentCode,
    this.requiredElectiveNote,
    this.capacity,
    this.language,
  })  : location = location ?? room,
        timeText = timeText ?? timeRange;
}
