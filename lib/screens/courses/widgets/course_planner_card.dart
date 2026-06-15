import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class PlannerCourseCard extends StatelessWidget {
  final PlannerCourse course;
  final bool hasConflict;
  final bool recommendedByBaoBao;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const PlannerCourseCard({
    super.key,
    required this.course,
    required this.hasConflict,
    this.recommendedByBaoBao = false,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: recommendedByBaoBao
                ? const Color(0xFFD8B4FE)
                : hasConflict
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFF1F5F9),
            width: recommendedByBaoBao ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: recommendedByBaoBao
                  ? const Color(0xFF7E3291).withValues(alpha: 0.10)
                  : hasConflict
                      ? const Color(0xFFFF2D55).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.055),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${course.code} - ${course.professor.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF020617),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(
                        label: course.type,
                        bgColor: _typeColor(course.type),
                        textColor: Colors.white,
                      ),
                      _Tag(
                        label: '${course.credits} CREDITS',
                        bgColor: const Color(0xFFF1F5F9),
                        textColor: const Color(0xFF64748B),
                      ),
                      _IconTag(
                        icon: Icons.calendar_month_rounded,
                        label: course.slotCode,
                      ),
                      _Tag(
                        label: course.limit < 0 ? 'LIMIT: N/A' : 'LIMIT: ${course.limit}',
                        bgColor: const Color(0xFFF1F5F9),
                        textColor: const Color(0xFF64748B),
                      ),
                      if (recommendedByBaoBao)
                        _Tag(
                          label: '★ RECOMMENDED BY BAO-BAO',
                          bgColor: const Color(0xFFF3E8FF),
                          textColor: const Color(0xFF7E3291),
                        ),
                      if (hasConflict)
                        _Tag(
                          label: '× CONFLICT',
                          bgColor: const Color(0xFFFEE2E2),
                          textColor: const Color(0xFFFF2D55),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onAdd,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: hasConflict
                      ? const Color(0xFFFEE2E2)
                      : recommendedByBaoBao
                          ? const Color(0xFFF3E8FF)
                          : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasConflict ? Icons.block_rounded : Icons.add_rounded,
                  color: hasConflict
                      ? const Color(0xFFFF2D55)
                      : const Color(0xFF7E3291),
                  size: hasConflict ? 22 : 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CORE':
        return Color.fromARGB(255, 204, 28, 28);
      case 'LAB':
        return const Color(0xFF14B8A6);
      case 'ELECTIVE':
        return const Color(0xFF7E3291);
      case 'LANGUAGE':
        return const Color(0xFF2563EB);
      case 'GE':
        return const Color(0xFFF97316);
      case 'PE':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _Tag({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: textColor,
        ),
      ),
    );
  }
}

class _IconTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}