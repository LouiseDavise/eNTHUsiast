import 'package:flutter/material.dart';

class AppEvent {
  final String id;
  final String title;
  final String code; // Course code
  final String time;
  final String type;
  final Color color;
  final String location;
  int progress;
  final DateTime dueDate;
  final List<Subtask> subtasks;

  AppEvent({
    required this.id,
    required this.title,
    required this.code,
    required this.time,
    required this.type,
    required this.color,
    this.location = 'Online',
    this.progress = 0,
    required this.dueDate,
    this.subtasks = const [],
  });
}

class BulletinItem {
  final String title;
  final String category;
  final List<Color> gradient;
  final IconData icon;

  BulletinItem({
    required this.title,
    required this.category,
    required this.gradient,
    required this.icon,
  });
}

class Subtask {
  final String id;
  final String text;
  bool completed;

  Subtask({required this.id, required this.text, this.completed = false});
}
