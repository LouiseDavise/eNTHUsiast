import 'package:flutter/material.dart';
import 'models.dart';

// Synced with AppTheme colors
const Color nthuPurple = Color.fromARGB(255, 114, 46, 133); // AppTheme.primary
const Color nthuPurpleLight = Color(0xFFEDE9FE); // AppTheme.primaryContainer
const Color nthuPurpleDark = Color.fromARGB(255, 124, 62, 231); // AppTheme.primaryLight

// Helper to convert date strings to DateTime
DateTime _parseDate(String dateStr) {
  final parts = dateStr.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

// Hardcoded Calendar Events (Mapped from TSX)
final Map<String, List<AppEvent>> initialCalendarEvents = {
  "2026-05-21": [
    AppEvent(id: "2026-05-21-0", title: "Calculus Homework", code: "MATH201", time: "23:59 Deadline", type: "Assignment", color: Colors.teal, dueDate: _parseDate("2026-05-21")),
    AppEvent(id: "2026-05-21-1", title: "Presentation Prep", code: "CS202", time: "17:00 - 18:30", location: "Study Room B", type: "Presentation", color: Colors.teal, dueDate: _parseDate("2026-05-21")),
    AppEvent(id: "2026-05-21-2", title: "UI Design Workshop", code: "DES115", time: "19:00 - 21:00", type: "Workshop", color: Colors.teal, dueDate: _parseDate("2026-05-21")),
    AppEvent(id: "2026-05-21-3", title: "Quick Quiz", code: "MATH201", time: "11:00 - 11:30", location: "Delta Hall 202", type: "Quiz", color: Colors.teal, dueDate: _parseDate("2026-05-21")),
  ],
  "2026-05-22": [
    AppEvent(id: "2026-05-22-0", title: "Interaction Design Project", code: "DES115", time: "23:59 Deadline", type: "Assignment", color: Colors.teal, dueDate: _parseDate("2026-05-22")),
    AppEvent(id: "2026-05-22-1", title: "Visual Systems Quiz", code: "DES301", time: "14:00 - 15:00", location: "Delta Hall 105", type: "Quiz", color: Colors.teal, dueDate: _parseDate("2026-05-22")),
  ],
  "2026-05-23": [
    AppEvent(id: "2026-05-23-0", title: "Mathematics Midterm", code: "MATH201", time: "09:00 - 11:30", location: "Delta Hall 202", type: "Midterm Exam", color: Colors.red, dueDate: _parseDate("2026-05-23")),
    AppEvent(id: "2026-05-23-1", title: "Team Workshop", code: "CS101", time: "13:00 - 15:00", location: "Lab 01", type: "Workshop", color: Colors.teal, dueDate: _parseDate("2026-05-23")),
  ],
  // ... (You can add the rest of the TSX dates here following the same pattern)
};

// Subtasks Map
final Map<String, List<Subtask>> initialSubtasksMap = {
  "2026-05-21-0": [
    Subtask(id: "st-m1", text: "Read Chapter 4 & 5", completed: true),
    Subtask(id: "st-m2", text: "Complete exercise set A", completed: true),
    Subtask(id: "st-m3", text: "Review proof of Convergence", completed: false),
    Subtask(id: "st-m4", text: "Final submission formatting", completed: false),
  ],
  "2026-05-22-0": [
    Subtask(id: "st-d1", text: "User research interviews", completed: true),
    Subtask(id: "st-d2", text: "Lo-fi wireframes", completed: true),
    Subtask(id: "st-d3", text: "Interactive prototype", completed: false),
  ],
};

// Update your bulletinItems list with this:
final List<BulletinItem> bulletinItems = [
  BulletinItem(
    title: "2026 NTHU\nMerit Scholarships",
    category: "Academic Excellence",
    gradient: [nthuPurpleDark, nthuPurple],
    icon: Icons.school_rounded,
  ),
  BulletinItem(
    title: "Meichu Games :\nNTHU vs NYCU",
    category: "Sports & Spirit",
    gradient: [Colors.orange.shade600, Colors.red.shade500],
    icon: Icons.rocket_launch_rounded,
  ),
  BulletinItem(
    title: "Global Internship Program",
    category: "Career Growth",
    // Use the Hex code for the exact Emerald look
    gradient: [Colors.teal.shade600, const Color(0xFF10B981)], 
    icon: Icons.menu_book_rounded,
  ),
];