import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class PlannerDetailSheet extends StatelessWidget {
  final PlannerCourse course;
  final VoidCallback onAdd;

  const PlannerDetailSheet({
    super.key,
    required this.course,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.91,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2D55),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${course.code} • ${course.credits} CREDITS',
                    style: const TextStyle(
                      fontSize: 12, // Increased from 9
                      fontWeight: FontWeight.w700, // Reduced from w900
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
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
              const SizedBox(height: 8),
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 26, // Adjusted slightly for balance
                  height: 1.1,
                  fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                  color: Color(0xFF020617),
                ),
              ),
              const SizedBox(height: 28),
              const _DetailSectionTitle(
                icon: Icons.star_border_rounded,
                color: Color(0xFFF59E0B),
                title: 'PROFESSOR & REVIEWS',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFCFE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          course.professor[0],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700, // Reduced from w900
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        course.professor,
                        style: const TextStyle(
                          fontSize: 16, // Increased from 15
                          fontWeight: FontWeight.w600, // Reduced from w900
                          color: Color(0xFF020617),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '⭐ ${course.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 14, // Increased from 13
                            fontWeight: FontWeight.w700, // Reduced from w900
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'REVIEWS', // Removed the duplicate count if it's visually too busy, or keep if needed
                          style: TextStyle(
                            fontSize: 10, // Increased from 8
                            fontWeight: FontWeight.w600, // Reduced from w900
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _DetailSectionTitle(
                icon: Icons.access_time_rounded,
                color: Color(0xFF3B82F6),
                title: 'SCHEDULE & LOCATION',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ScheduleInfoBox(
                      label: 'TIME SLOT',
                      value: course.timeSlot,
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScheduleInfoBox(
                      label: 'LOCATION',
                      value: course.location,
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CapacityBox(
                limit: course.limit,
              ),
              // const SizedBox(height: 28),
              // const _DetailSectionTitle(
              //   icon: Icons.calendar_month_rounded,
              //   color: Color(0xFFFF5B6E),
              //   title: 'ACADEMIC DEADLINES',
              // ),
              // const SizedBox(height: 14),
              // Row(
              //   children: [
              //     Expanded(
              //       child: _DeadlineBox(
              //         label: 'MIDTERM',
              //         value: course.midtermDate,
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     Expanded(
              //       child: _DeadlineBox(
              //         label: 'FINAL',
              //         value: course.finalDate,
              //       ),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 12),
              // _DeadlineBox(
              //   label: 'PROJECT FINAL',
              //   value: course.projectDate,
              // ),
              // const SizedBox(height: 28),
              // const _DetailSectionTitle(
              //   icon: Icons.check_box_outlined,
              //   color: Color(0xFF10B981),
              //   title: 'GRADING BREAKDOWN',
              // ),
              // const SizedBox(height: 14),
              // ClipRRect(
              //   borderRadius: BorderRadius.circular(999),
              //   child: SizedBox(
              //     height: 12,
              //     child: Row(
              //       children: course.grading.entries.map((entry) {
              //         return Expanded(
              //           flex: entry.value,
              //           child: Container(
              //             color: _gradingColor(entry.key),
              //           ),
              //         );
              //       }).toList(),
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 14),
              // Wrap(
              //   spacing: 18,
              //   runSpacing: 10,
              //   children: course.grading.entries.map((entry) {
              //     return _LegendItem(
              //       label: entry.key.toUpperCase(),
              //       percent: entry.value,
              //       color: _gradingColor(entry.key),
              //     );
              //   }).toList(),
              // ),
              const SizedBox(height: 28),
              const _DetailSectionTitle(
                icon: Icons.groups_rounded,
                color: Color(0xFF9333EA),
                title: 'COURSE SYLLABUS',
              ),
              const SizedBox(height: 14),
              ...course.syllabus.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 12, // Increased from 10
                              fontWeight: FontWeight.w700, // Reduced from w900
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 14, // Increased from 12 for readability
                            fontWeight: FontWeight.w500, // Reduced from w900
                            height: 1.3,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3291),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'ADD TO MY PLAN',
                  style: TextStyle(
                    fontSize: 14, // Increased from 11
                    fontWeight: FontWeight.w700, // Reduced from w900
                    letterSpacing: 1.0, // Toned down letter spacing
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Color _gradingColor(String key) {
    final lower = key.toLowerCase();

    if (lower.contains('exam')) {
      return const Color(0xFF7E3291);
    }

    if (lower.contains('project') || lower.contains('homework')) {
      return const Color(0xFF3B82F6);
    }

    return const Color(0xFF10B981);
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _DetailSectionTitle({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11, // Increased from 10
            fontWeight: FontWeight.w700, // Reduced from w900
            letterSpacing: 1.2, // Toned down
            color: Color(0xFF475569), // Softened from pure black
          ),
        ),
      ],
    );
  }
}

class _DeadlineBox extends StatelessWidget {
  final String label;
  final String value;

  const _DeadlineBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10, // Increased from 8
              fontWeight: FontWeight.w600, // Reduced from w900
              letterSpacing: 0.5,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14, // Increased from 12
              fontWeight: FontWeight.w700, // Reduced from w900
              color: Color(0xFF020617),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      child: Row(
        children: [
          Container(
            width: 8, // Increased slightly
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11, // Increased from 9
                fontWeight: FontWeight.w600, // Reduced from w900
                color: Color(0xFF475569),
              ),
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 12, // Increased from 9
              fontWeight: FontWeight.w700, // Reduced from w900
              color: Color(0xFF020617),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleInfoBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ScheduleInfoBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10, // Increased from 8
              fontWeight: FontWeight.w600, // Reduced from w900
              letterSpacing: 0.5,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                icon,
                size: 14, // Increased slightly
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13, // Increased from 11
                    fontWeight: FontWeight.w700, // Reduced from w900
                    color: Color(0xFF020617),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapacityBox extends StatelessWidget {
  final int limit;

  const _CapacityBox({
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = limit >= 0;
    final limitText = hasLimit ? '$limit STUDENTS' : 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'COURSE CAPACITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              Text(
                limitText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7E3291),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: hasLimit ? 1.0 : 0.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7E3291),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasLimit
                ? 'This course has an enrollment limit of $limit students. Registration is subject to department approval and available space at the time of enrollment.'
                : 'No enrollment limit information is provided. Registration is subject to department approval and available space at the time of enrollment.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}