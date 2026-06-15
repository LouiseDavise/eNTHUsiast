import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';
import '../../../providers/language_provider.dart';
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

  // Localized label helper
  String _getTranslatedLabel(String label, bool isChinese) {
    if (!isChinese) return label;
    return {
          'Credits': '學分',
          'Limit': '限額',
          'Type': '類別',
          'COURSE INFORMATION': '課程資訊',
          'Department': '系所',
          'Professor': '教授',
          'Location': '地點',
          'Time': '時間',
          'Language': '授課語言',
          'Requirement': '備註',
          'QUICK NOTE': '課程筆記',
        }[label] ??
        label;
  }

  String _buildQuickNote(bool isChinese) {
    final creditsText = course.credits == null ? 'N/A' : '${course.credits}';
    final lang = displayTimetableCourseLanguage(course.language);
    final prof = course.teacher?.trim().isNotEmpty == true
        ? course.teacher!.trim()
        : (isChinese ? '待定' : 'TBA');
    final type = course.courseType ?? (isChinese ? '課程' : 'course');

    if (isChinese) {
      return '這是一門 $creditsText 學分的 $type 課程。由 $prof 授課，教學語言為 $lang。時間：${_getTimeText(isChinese)}。';
    }
    return 'This course is a $creditsText-credit ${course.courseType ?? 'course'} course. '
        'It is taught by $prof. '
        'The instruction language is $lang. '
        'Time: ${_getTimeText(isChinese)}.';
  }

  String _getTimeText(bool isChinese) {
    final day = course.dayLabel?.trim() ?? '';
    final time = course.timeText?.trim() ?? '';
    final slot = course.slotCode?.trim() ?? '';
    final mainTime = [day, time].where((e) => e.isNotEmpty).join(' ');
    if (mainTime.isEmpty && slot.isEmpty) return isChinese ? '無' : 'N/A';
    return mainTime.isEmpty
        ? slot
        : (slot.isEmpty ? mainTime : '$mainTime ($slot)');
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.watch(context);
    final isChinese = language.isChinese;
    final typeStyle = _getTimetableCourseTypeStyle(course.courseType);

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.82,
      minChildSize: 0.45,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
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
                          borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 22),

              // Top Profile Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                        color: typeStyle.softColor,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: typeStyle.borderColor)),
                    child: Icon(typeStyle.icon,
                        color: typeStyle.mainColor, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: typeStyle.mainColor,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(course.code,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: Colors.white))),
                        const SizedBox(height: 8),
                        Text(course.title,
                            style: const TextStyle(
                                fontSize: 21,
                                height: 1.18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        Text(
                            '${isChinese ? '教授：' : 'Professor: '}${course.teacher ?? 'N/A'}',
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats Row
              Row(
                children: [
                  Expanded(
                      child: _SmallStatCard(
                          label: _getTranslatedLabel('Credits', isChinese),
                          value: course.credits?.toString() ?? 'N/A',
                          icon: Icons.workspace_premium_rounded,
                          typeStyle: typeStyle)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _SmallStatCard(
                          label: _getTranslatedLabel('Limit', isChinese),
                          value: (course.capacity ?? 0) <= 0
                              ? 'N/A'
                              : '${course.capacity}',
                          icon: Icons.groups_rounded,
                          typeStyle: typeStyle)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _SmallStatCard(
                          label: _getTranslatedLabel('Type', isChinese),
                          value: course.courseType ??
                              (isChinese ? '課程' : 'COURSE'),
                          icon: typeStyle.icon,
                          typeStyle: typeStyle)),
                ],
              ),
              const SizedBox(height: 18),

              // Details
              _SectionTitle(
                  icon: Icons.info_outline_rounded,
                  title: _getTranslatedLabel('COURSE INFORMATION', isChinese),
                  typeStyle: typeStyle),
              const SizedBox(height: 12),
              _DetailInfoRow(
                  icon: Icons.business_rounded,
                  label: _getTranslatedLabel('Department', isChinese),
                  value: course.departmentFullName ?? 'N/A',
                  typeStyle: typeStyle),
              const SizedBox(height: 10),
              _DetailInfoRow(
                  icon: Icons.location_on_rounded,
                  label: _getTranslatedLabel('Location', isChinese),
                  value: course.location ?? 'N/A',
                  typeStyle: typeStyle),
              const SizedBox(height: 10),
              _DetailInfoRow(
                  icon: Icons.access_time_rounded,
                  label: _getTranslatedLabel('Time', isChinese),
                  value: _getTimeText(isChinese),
                  typeStyle: typeStyle),
              const SizedBox(height: 10),
              _DetailInfoRow(
                  icon: Icons.language_rounded,
                  label: _getTranslatedLabel('Language', isChinese),
                  value: displayTimetableCourseLanguage(course.language),
                  typeStyle: typeStyle),

              const SizedBox(height: 22),
              _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: _getTranslatedLabel('QUICK NOTE', isChinese),
                  typeStyle: typeStyle),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: typeStyle.borderColor.withValues(alpha: 0.8))),
                child: Text(_buildQuickNote(isChinese),
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B))),
              ),
            ],
          ),
        );
      },
    );
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
