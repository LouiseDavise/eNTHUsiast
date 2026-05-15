import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';

/// Slot indices match the periods list in TimetableGrid:
/// 0=1(08:00), 1=2(09:00), 2=3(10:10), 3=4(11:10),
/// 4=n(12:10), 5=5(13:20), 6=6(14:20), 7=7(15:30),
/// 8=8(16:30), 9=9(17:30), 10=a(18:30), 11=b(19:30),
/// 12=c(20:30), 13=d(21:30)

final List<CourseItem> dummySchedule = [
  // ── Computer Architecture ──────────────────────────────────────────────────
  CourseItem(day: 2, startSlot: 2, duration: 2, title: 'Computer Archite...', code: 'EECS 102', bg: const Color(0xFFFFF7ED), border: const Color(0xFFFED7AA), text: const Color(0xFFC2410C)),
  CourseItem(day: 4, startSlot: 3, duration: 1, title: 'Computer Archite...', code: 'EECS 102', bg: const Color(0xFFFFF7ED), border: const Color(0xFFFED7AA), text: const Color(0xFFC2410C)),

  // ── Computer Networks ──────────────────────────────────────────────────────
  CourseItem(day: 1, startSlot: 2, duration: 2, title: 'Computer Networks', code: 'EECS 105', bg: const Color(0xFFEFF6FF), border: const Color(0xFFBFDBFE), text: const Color(0xFF1D4ED8)),
  CourseItem(day: 3, startSlot: 2, duration: 1, title: 'Computer Networks', code: 'EECS 105', bg: const Color(0xFFEFF6FF), border: const Color(0xFFBFDBFE), text: const Color(0xFF1D4ED8)),

  // ── Software Studio ────────────────────────────────────────────────────────
  CourseItem(day: 3, startSlot: 5, duration: 3, title: 'Software Studio', code: 'LAB 205', bg: const Color(0xFFECFDF5), border: const Color(0xFFA7F3D0), text: const Color(0xFF065F46)),

  // ── Hardware Design & Lab ──────────────────────────────────────────────────
  CourseItem(day: 1, startSlot: 6, duration: 3, title: 'Hardware Design ...', code: 'LAB 301', bg: const Color(0xFFF5F3FF), border: const Color(0xFFDDD6FE), text: const Color(0xFF6D28D9)),

  // ── Algorithms ────────────────────────────────────────────────────────────
  CourseItem(day: 2, startSlot: 0, duration: 2, title: 'Algorithms', code: 'EECS 112', bg: const Color(0xFFF0FDFA), border: const Color(0xFF99F6E4), text: const Color(0xFF0F766E)),
  CourseItem(day: 4, startSlot: 1, duration: 1, title: 'Algorithms', code: 'EECS 112', bg: const Color(0xFFF0FDFA), border: const Color(0xFF99F6E4), text: const Color(0xFF0F766E)),

  // ── Probability ────────────────────────────────────────────────────────────
  CourseItem(day: 2, startSlot: 5, duration: 2, title: 'Probability', code: 'MATH 202', bg: const Color(0xFFFAF5FF), border: const Color(0xFFE9D5FF), text: const Color(0xFF7C3AED)),
  CourseItem(day: 4, startSlot: 6, duration: 1, title: 'Probability', code: 'MATH 202', bg: const Color(0xFFFAF5FF), border: const Color(0xFFE9D5FF), text: const Color(0xFF7C3AED)),

  // ── Data Structures ────────────────────────────────────────────────────────
  CourseItem(day: 1, startSlot: 0, duration: 2, title: 'Data Structur...', code: 'ENG 402', bg: const Color(0xFFFFF1F2), border: const Color(0xFFFECACA), text: const Color(0xFFB91C1C)),
  CourseItem(day: 3, startSlot: 1, duration: 1, title: 'Data Structur...', code: 'ENG 402', bg: const Color(0xFFFFF1F2), border: const Color(0xFFFECACA), text: const Color(0xFFB91C1C)),

  // ── Linear Algebra ─────────────────────────────────────────────────────────
  CourseItem(day: 2, startSlot: 7, duration: 2, title: 'Linear Algebra', code: 'M03 Aud...', bg: const Color(0xFFFFFBEB), border: const Color(0xFFFDE68A), text: const Color(0xFFB45309)),
  CourseItem(day: 4, startSlot: 8, duration: 1, title: 'Linear Algebra', code: 'M03 Aud...', bg: const Color(0xFFFFFBEB), border: const Color(0xFFFDE68A), text: const Color(0xFFB45309)),

  // ── Intro to Programming ───────────────────────────────────────────────────
  CourseItem(day: 5, startSlot: 0, duration: 3, title: 'Intro to Progra...', code: 'LAB 101', bg: const Color(0xFFEEF2FF), border: const Color(0xFFC7D2FE), text: const Color(0xFF4338CA)),

  // ── Philosophy of Mind ─────────────────────────────────────────────────────
  CourseItem(day: 2, startSlot: 10, duration: 3, title: 'Philosophy of Mind', code: 'GEN 202', bg: const Color(0xFFF8FAFC), border: const Color(0xFFCBD5E1), text: const Color(0xFF475569)),
];