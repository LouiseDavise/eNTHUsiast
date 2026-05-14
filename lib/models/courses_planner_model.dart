import 'package:flutter/material.dart';

class PlannerCourse {
  final String id;
  final String code;
  final String title;
  final String professor;
  final int credits;
  final String type;
  final String department;
  final int limit;
  final double rating;
  final int reviews;
  final String midtermDate;
  final String finalDate;
  final String projectDate;
  final Map<String, int> grading;
  final List<String> syllabus;

  final String timeSlot;
  final String location;
  final String slotCode;

  final int day;
  final int startSlot;
  final int duration;
  final Color color;

  const PlannerCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.professor,
    required this.credits,
    required this.type,
    required this.department,
    required this.limit,
    required this.rating,
    required this.reviews,
    required this.midtermDate,
    required this.finalDate,
    required this.projectDate,
    required this.grading,
    required this.syllabus,
    required this.timeSlot,
    required this.location,
    required this.slotCode,
    required this.day,
    required this.startSlot,
    required this.duration,
    required this.color,
  });
}