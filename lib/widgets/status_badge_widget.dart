import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum TaskStatus { critical, coursework, todo, submitted, graded }

class StatusBadgeWidget extends StatelessWidget {
  final TaskStatus status;
  final String? customLabel;
  final double fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.customLabel,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        customLabel ?? config.label,
        style: GoogleFonts.dmSans(
          color: config.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  _BadgeConfig _getConfig(TaskStatus status) {
    switch (status) {
      case TaskStatus.critical:
        return _BadgeConfig(
          label: 'CRITICAL',
          backgroundColor: AppTheme.critical,
          textColor: Colors.white,
        );
      case TaskStatus.coursework:
        return _BadgeConfig(
          label: 'COURSEWORK',
          backgroundColor: AppTheme.teal,
          textColor: Colors.white,
        );
      case TaskStatus.todo:
        return _BadgeConfig(
          label: 'TODO',
          backgroundColor: AppTheme.primary,
          textColor: Colors.white,
        );
      case TaskStatus.submitted:
        return _BadgeConfig(
          label: 'SUBMITTED',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      case TaskStatus.graded:
        return _BadgeConfig(
          label: 'GRADED',
          backgroundColor: Color(0xFF6B7280),
          textColor: Colors.white,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}
