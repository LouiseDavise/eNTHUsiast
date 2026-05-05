import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/task_model.dart';
import 'status_badge_widget.dart';

class UpcomingPreviewWidget extends StatelessWidget {
  final List<TaskModel> tasks;
  final VoidCallback onViewAll;

  const UpcomingPreviewWidget({
    super.key,
    required this.tasks,
    required this.onViewAll,
  });

  Color _borderColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.critical:
        return AppTheme.critical;
      case TaskStatus.coursework:
        return AppTheme.teal;
      case TaskStatus.todo:
        return AppTheme.primary;
      default:
        return Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: AppTheme.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Upcoming',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'ALL',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Color(0xFF6B7280),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.map(
          (task) => _TaskPreviewCard(
            task: task,
            borderColor: _borderColor(task.status),
          ),
        ),
      ],
    );
  }
}

class _TaskPreviewCard extends StatelessWidget {
  final TaskModel task;
  final Color borderColor;

  const _TaskPreviewCard({required this.task, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          task.courseCode,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          task.countdownLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.orange,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: task.progressPercent,
                              backgroundColor: Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                task.progressPercent > 0
                                    ? AppTheme.teal
                                    : Color(0xFFE5E7EB),
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(task.progressPercent * 100).toInt()}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
