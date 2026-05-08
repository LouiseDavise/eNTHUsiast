import 'package:flutter/material.dart';

class CourseItem {
  final int day;        // 1 = Mon … 5 = Fri
  final int startSlot;  // 0-based index into timeSlots
  final int duration;   // number of slots spanned
  final String title;
  final String code;
  final Color bg;
  final Color border;
  final Color text;

  const CourseItem({
    required this.day,
    required this.startSlot,
    required this.duration,
    required this.title,
    required this.code,
    required this.bg,
    required this.border,
    required this.text,
  });
}