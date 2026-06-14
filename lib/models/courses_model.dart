import 'package:flutter/material.dart';

class CourseItem {
  final int day;
  final int startSlot;
  final int duration;

  final String title;
  final String code;

  final String? titleZh;
  final String? titleEn;
  final String? location;
  final String? teacher;
  final String? slotCode;
  final String? timeText;
  final String? dayLabel;

  final int? credits;
  final int? capacity;

  final String? departmentCode;
  final String? departmentFullName;
  final String? language;
  final String? requiredElectiveNote;
  final String? courseType;

  final Color bg;
  final Color border;
  final Color text;

  const CourseItem({
    required this.day,
    required this.startSlot,
    required this.duration,
    required this.title,
    required this.code,
    this.titleZh,
    this.titleEn,
    this.location,
    this.teacher,
    this.slotCode,
    this.timeText,
    this.dayLabel,
    this.credits,
    this.capacity,
    this.departmentCode,
    this.departmentFullName,
    this.language,
    this.requiredElectiveNote,
    this.courseType,
    required this.bg,
    required this.border,
    required this.text,
  });
}
