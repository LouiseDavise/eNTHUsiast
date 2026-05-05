import '../widgets/status_badge_widget.dart';

class TaskModel {
  final String id;
  final String courseCode;
  final String title;
  final TaskStatus status;
  final DateTime deadline;
  final double progressPercent;
  final String description;

  TaskModel({
    required this.id,
    required this.courseCode,
    required this.title,
    required this.status,
    required this.deadline,
    required this.progressPercent,
    this.description = '',
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      courseCode: map['courseCode'] as String,
      title: map['title'] as String,
      status: _statusFromString(map['status'] as String),
      deadline: DateTime.parse(map['deadline'] as String),
      progressPercent: (map['progressPercent'] as num).toDouble(),
      description: map['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'courseCode': courseCode,
    'title': title,
    'status': _statusToString(status),
    'deadline': deadline.toIso8601String(),
    'progressPercent': progressPercent,
    'description': description,
  };

  static TaskStatus _statusFromString(String v) {
    switch (v) {
      case 'critical':
        return TaskStatus.critical;
      case 'coursework':
        return TaskStatus.coursework;
      case 'todo':
        return TaskStatus.todo;
      case 'submitted':
        return TaskStatus.submitted;
      case 'graded':
        return TaskStatus.graded;
      default:
        return TaskStatus.todo;
    }
  }

  static String _statusToString(TaskStatus s) {
    switch (s) {
      case TaskStatus.critical:
        return 'critical';
      case TaskStatus.coursework:
        return 'coursework';
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.submitted:
        return 'submitted';
      case TaskStatus.graded:
        return 'graded';
    }
  }

  String get countdownLabel {
    final now = DateTime(2026, 5, 5, 12, 38);
    final diff = deadline.difference(now);
    if (diff.isNegative) return 'OVERDUE';
    final weeks = diff.inDays ~/ 7;
    final days = diff.inDays % 7;
    final hours = diff.inHours % 24;
    if (weeks > 0) return '${weeks}W ${days}D ${hours}H';
    if (days > 0) return '${days}D ${hours}H';
    return '${hours}H';
  }
}
