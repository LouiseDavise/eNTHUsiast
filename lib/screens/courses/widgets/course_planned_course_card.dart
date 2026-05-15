import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class PlannedCourseCard extends StatelessWidget {
  final PlannerCourse course;
  final VoidCallback onRemove;

  const PlannedCourseCard({
    super.key,
    required this.course,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: course.color,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700, // Reduced from w900
                    color: Color(0xFF020617),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${course.code} • ${course.credits} CREDITS',
                  style: const TextStyle(
                    fontSize: 12, // Increased from 9
                    fontWeight: FontWeight.w600, // Reduced from w900
                    letterSpacing: 0.5, // Softened from 1.0
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onRemove,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}