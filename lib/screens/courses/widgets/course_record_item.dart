import 'package:flutter/material.dart';

import '../../../models/graduation_verification_model.dart';

class CourseRecordItem extends StatelessWidget {
  final GraduationCourseRecord record;

  const CourseRecordItem({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isPassed = record.status == 'passed';
    final isInProgress = record.status == 'inProgress';

    final statusText = isPassed
        ? 'PASSED'
        : isInProgress
            ? 'IN PROGRESS'
            : 'NOT PASSED';

    final statusBgColor = isPassed
        ? const Color(0xFFDCFCE7)
        : isInProgress
            ? const Color(0xFFDBEAFE)
            : const Color(0xFFFEE2E2);

    final statusTextColor = isPassed
        ? const Color(0xFF16A34A)
        : isInProgress
            ? const Color(0xFF2563EB)
            : const Color(0xFFDC2626);

    final iconColor = isPassed
        ? const Color(0xFF22C55E)
        : isInProgress
            ? const Color(0xFF3B82F6)
            : const Color(0xFFEF4444);

    final iconBgColor = isPassed
        ? const Color(0xFFECFDF5)
        : isInProgress
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFFEF2F2);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Slightly increased padding
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, // Increased from 26 to balance larger text
            height: 28,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: iconColor.withOpacity(0.35),
              ),
            ),
            child: Icon(
              isPassed
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16, // Increased slightly
              color: iconColor,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontSize: 15, // Increased from 12
                    fontWeight: FontWeight.w700, // Reduced from w900
                    color: Color(0xFF020617),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${record.credits} CREDITS',
                      style: const TextStyle(
                        fontSize: 11, // Increased from 8
                        fontWeight: FontWeight.w600, // Reduced from w900
                        letterSpacing: 0.5, // Reduced from 0.8
                        color: Color(0xFF94A3B8),
                      ),
                    ),

                    if (record.grade.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, // Slightly increased
                          vertical: 3, // Slightly increased
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6), // Softened
                        ),
                        child: Text(
                          'GRADE: ${record.grade}',
                          style: const TextStyle(
                            fontSize: 10, // Increased from 8
                            fontWeight: FontWeight.w700, // Reduced from w900
                            letterSpacing: 0.5,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), // Increased from 7/4
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(8), // Increased from 7
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10, // Increased from 8
                fontWeight: FontWeight.w700, // Reduced from w900
                letterSpacing: 0.5,
                color: statusTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}