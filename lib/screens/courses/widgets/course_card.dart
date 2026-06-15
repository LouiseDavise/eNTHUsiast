import 'package:flutter/material.dart';
import 'package:enthusiast/models/courses_model.dart';

class CourseCard extends StatelessWidget {
  final CourseItem course;

  const CourseCard({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final background = Color.alphaBlend(
      course.bg.withValues(alpha: 0.10),
      Colors.white,
    );
    final borderColor = course.border.withValues(alpha: 0.82);
    final textColor = course.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showCourseDetails(context),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.05),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  course.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: course.duration >= 2 ? 11.2 : 10.2,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    height: 1.18,
                    letterSpacing: -0.1,
                  ),
                  maxLines: course.duration >= 2 ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (course.timeRange.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    course.timeRange,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.2,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.84),
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (course.room.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    course.room,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.2,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.74),
                      height: 1.12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final background = Color.alphaBlend(
          course.bg.withValues(alpha: 0.14),
          Colors.white,
        );

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: course.border.withValues(alpha: 0.82),
                        ),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: course.text),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        course.title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow(label: 'Course No', value: course.courseNo.isEmpty ? course.code : course.courseNo),
                _DetailRow(label: 'Time', value: course.timeRange),
                _DetailRow(label: 'Slot', value: course.slotCode),
                _DetailRow(label: 'Room', value: course.room),
                _DetailRow(label: 'Teacher', value: course.teacher),
                if (course.credits > 0)
                  _DetailRow(label: 'Credits', value: course.credits.toString()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

