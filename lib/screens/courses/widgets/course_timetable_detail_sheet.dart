import 'package:flutter/material.dart';

import '../../../models/courses_model.dart';

String displayTimetableCourseLanguage(String? language) {
  final text = (language ?? '').trim();
  final lower = text.toLowerCase();

  if (text.isEmpty) {
    return 'N/A';
  }

  if (lower.contains('english') ||
      lower.contains('eng') ||
      text.contains('?')) {
    return 'English';
  }

  if (lower.contains('chinese') ||
      lower.contains('mandarin') ||
      lower.contains('zh') ||
      text.contains('?') ||
      text.contains('?')) {
    return 'Chinese';
  }

  return text;
}

class _CourseTypeStyle {
  final Color mainColor;
  final Color softColor;
  final Color borderColor;
  final IconData icon;

  const _CourseTypeStyle({
    required this.mainColor,
    required this.softColor,
    required this.borderColor,
    required this.icon,
  });
}

_CourseTypeStyle _getTimetableCourseTypeStyle(String? type) {
  final upper = (type ?? '').toUpperCase().trim();

  switch (upper) {
    case 'CORE':
      return const _CourseTypeStyle(
        mainColor: Color(0xFFFF2D55),
        softColor: Color(0xFFFFEEF3),
        borderColor: Color(0xFFFFC2D1),
        icon: Icons.local_fire_department_rounded,
      );

    case 'GE':
      return const _CourseTypeStyle(
        mainColor: Color(0xFFFF6B2C),
        softColor: Color(0xFFFFF1E8),
        borderColor: Color(0xFFFFD1B8),
        icon: Icons.public_rounded,
      );

    case 'LAB':
      return const _CourseTypeStyle(
        mainColor: Color(0xFF14B8A6),
        softColor: Color(0xFFE6FFFB),
        borderColor: Color(0xFFA7F3D0),
        icon: Icons.science_rounded,
      );

    case 'PE':
      return const _CourseTypeStyle(
        mainColor: Color(0xFF22C55E),
        softColor: Color(0xFFEFFDF4),
        borderColor: Color(0xFFBBF7D0),
        icon: Icons.directions_run_rounded,
      );

    case 'LANGUAGE':
    case 'LANG':
      return const _CourseTypeStyle(
        mainColor: Color(0xFF3B82F6),
        softColor: Color(0xFFEFF6FF),
        borderColor: Color(0xFFBFDBFE),
        icon: Icons.language_rounded,
      );

    case 'ELECTIVE':
      return const _CourseTypeStyle(
        mainColor: Color(0xFF7E3291),
        softColor: Color(0xFFF3E8FF),
        borderColor: Color(0xFFE9D5FF),
        icon: Icons.menu_book_rounded,
      );

    default:
      return const _CourseTypeStyle(
        mainColor: Color(0xFF64748B),
        softColor: Color(0xFFF1F5F9),
        borderColor: Color(0xFFE2E8F0),
        icon: Icons.menu_book_rounded,
      );
  }
}

class CourseTimetableDetailSheet extends StatelessWidget {
  final CourseItem course;

  const CourseTimetableDetailSheet({
    super.key,
    required this.course,
  });

  String get _courseType => course.courseType?.trim().isNotEmpty == true
      ? course.courseType!.trim()
      : 'COURSE';

  String get _professor => course.teacher?.trim().isNotEmpty == true
      ? course.teacher!.trim()
      : 'N/A';

  String get _department {
    final full = course.departmentFullName?.trim();
    if (full != null && full.isNotEmpty) return full;

    final code = course.departmentCode?.trim();
    if (code != null && code.isNotEmpty) return code;

    return 'N/A';
  }

  String get _location => course.location?.trim().isNotEmpty == true
      ? course.location!.trim()
      : 'N/A';

  String get _timeText {
    final day = course.dayLabel?.trim() ?? '';
    final time = course.timeText?.trim() ?? '';
    final slot = course.slotCode?.trim() ?? '';

    final mainTime = [day, time].where((e) => e.isNotEmpty).join(' ');

    if (mainTime.isEmpty && slot.isEmpty) return 'N/A';
    if (mainTime.isEmpty) return slot;
    if (slot.isEmpty) return mainTime;

    return '$mainTime ($slot)';
  }

  String get _requiredNote => course.requiredElectiveNote?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final typeStyle = _getTimetableCourseTypeStyle(course.courseType);

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.82,
      minChildSize: 0.45,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: typeStyle.softColor,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: typeStyle.borderColor,
                      ),
                    ),
                    child: Icon(
                      typeStyle.icon,
                      color: typeStyle.mainColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: typeStyle.mainColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            course.code,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.title,
                          style: const TextStyle(
                            fontSize: 21,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Professor: $_professor',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _SmallStatCard(
                      label: 'Credits',
                      value: course.credits == null ? 'N/A' : '${course.credits}',
                      icon: Icons.workspace_premium_rounded,
                      typeStyle: typeStyle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallStatCard(
                      label: 'Limit',
                      value: course.capacity == null || course.capacity! <= 0
                          ? 'N/A'
                          : '${course.capacity}',
                      icon: Icons.groups_rounded,
                      typeStyle: typeStyle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallStatCard(
                      label: 'Type',
                      value: _courseType,
                      icon: typeStyle.icon,
                      typeStyle: typeStyle,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _SectionTitle(
                icon: Icons.info_outline_rounded,
                title: 'COURSE INFORMATION',
                typeStyle: typeStyle,
              ),

              const SizedBox(height: 12),

              _DetailInfoRow(
                icon: Icons.business_rounded,
                label: 'Department',
                value: _department,
                typeStyle: typeStyle,
              ),
              const SizedBox(height: 10),
              _DetailInfoRow(
                icon: Icons.person_rounded,
                label: 'Professor',
                value: _professor,
                typeStyle: typeStyle,
              ),
              const SizedBox(height: 10),
              _DetailInfoRow(
                icon: Icons.location_on_rounded,
                label: 'Location',
                value: _location,
                typeStyle: typeStyle,
              ),
              const SizedBox(height: 10),
              _DetailInfoRow(
                icon: Icons.access_time_rounded,
                label: 'Time',
                value: _timeText,
                typeStyle: typeStyle,
              ),
              const SizedBox(height: 10),
              _DetailInfoRow(
                icon: Icons.language_rounded,
                label: 'Language',
                value: displayTimetableCourseLanguage(course.language),
                typeStyle: typeStyle,
              ),

              if (_requiredNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailInfoRow(
                  icon: Icons.assignment_rounded,
                  label: 'Requirement',
                  value: _requiredNote,
                  typeStyle: typeStyle,
                ),
              ],

              const SizedBox(height: 22),

              _SectionTitle(
                icon: Icons.auto_awesome_rounded,
                title: 'QUICK NOTE',
                typeStyle: typeStyle,
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: typeStyle.borderColor.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: typeStyle.mainColor.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  _buildQuickNote(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildQuickNote() {
    final creditsText = course.credits == null ? 'N/A' : '${course.credits}';
    final language = displayTimetableCourseLanguage(course.language);

    return 'This course is a $creditsText-credit $_courseType course. '
        'It is taught by $_professor. '
        'The instruction language is $language. '
        'Time: $_timeText.';
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final _CourseTypeStyle typeStyle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.typeStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: typeStyle.mainColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final _CourseTypeStyle typeStyle;

  const _SmallStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.typeStyle,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'N/A' : value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: typeStyle.borderColor.withValues(alpha: 0.75),
        ),
        boxShadow: [
          BoxShadow(
            color: typeStyle.mainColor.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: typeStyle.mainColor,
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _CourseTypeStyle typeStyle;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.typeStyle,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'N/A' : value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: typeStyle.borderColor.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: typeStyle.mainColor.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: typeStyle.mainColor,
          ),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


