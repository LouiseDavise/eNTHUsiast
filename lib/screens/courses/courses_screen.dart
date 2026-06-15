import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:enthusiast/models/courses_model.dart';
import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/screens/courses/courses_material_screen.dart';
import 'package:enthusiast/screens/courses/courses_planner_screen.dart';
import 'package:enthusiast/screens/courses/graduation_verification_screen.dart';
import 'package:enthusiast/screens/courses/utilities/course_schedule_mapper.dart';
import 'package:enthusiast/screens/courses/widgets/menu_square_button.dart';
import 'package:enthusiast/screens/courses/widgets/menu_wide_button.dart';
import 'package:enthusiast/screens/courses/widgets/timetable_grid.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  static const String _testStudentId = String.fromEnvironment('COURSE_TEST_STUDENT_ID');

  final List<String> _semesters = CourseScheduleMapper.semesterOrder;
  int _semesterIndex = CourseScheduleMapper.semesterOrder.length - 1;

  Future<List<CourseItem>>? _scheduleFuture;
  dynamic _lastScheduleData;
  String? _lastSemester;

  @override
  Widget build(BuildContext context) {
    final scheduleData = context.watch<CcxpDataProvider>().scheduleData;
    final selectedSemester = _semesters[_semesterIndex];

    if (!identical(_lastScheduleData, scheduleData) || _lastSemester != selectedSemester) {
      _lastScheduleData = scheduleData;
      _lastSemester = selectedSemester;
      _scheduleFuture = CourseScheduleMapper.buildSemesterSchedule(
        semester: selectedSemester,
        fallbackScheduleData: scheduleData,
        studentIdOverride: _testStudentId,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SemesterHeader(
                title: selectedSemester,
                canGoPrevious: _semesterIndex > 0,
                canGoNext: _semesterIndex < _semesters.length - 1,
                onPrevious: _semesterIndex > 0
                    ? () => setState(() => _semesterIndex -= 1)
                    : null,
                onNext: _semesterIndex < _semesters.length - 1
                    ? () => setState(() => _semesterIndex += 1)
                    : null,
              ),
              if (_testStudentId.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DemoStudentBanner(studentId: _testStudentId),
              ],
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFEAEAF2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: FutureBuilder<List<CourseItem>>(
                  future: _scheduleFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 420,
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF7B2CBF)),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _ScheduleStateMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load timetable',
                        subtitle: snapshot.error.toString(),
                      );
                    }

                    final schedule = snapshot.data ?? const <CourseItem>[];

                    if (schedule.isEmpty) {
                      return _ScheduleStateMessage(
                        icon: Icons.calendar_month_outlined,
                        title: 'No timetable data for $selectedSemester',
                        subtitle: 'This semester may not have synced course time data yet.',
                      );
                    }

                    return TimetableGrid(schedule: schedule);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MenuSquareButton(
                      title: 'Course\nMaterials',
                      icon: Icons.menu_book_rounded,
                      activeColor: const Color(0xFF7B2CBF),
                      inactiveBgColor: const Color(0xFFE9D5FF),
                      inactiveIconColor: const Color(0xFF7B2CBF),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourseMaterialsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: MenuSquareButton(
                      title: 'Course\nPlanner',
                      icon: Icons.search_rounded,
                      activeColor: const Color(0xFF2563EB),
                      inactiveBgColor: const Color(0xFFEFF6FF),
                      inactiveIconColor: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CoursePlannerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MenuWideButton(
                title: 'Graduation Verification',
                subtitle: 'CHECK YOUR DEGREE PROGRESS',
                icon: Icons.school_outlined,
                activeColor: const Color(0xFFF97316),
                inactiveBgColor: const Color(0xFFFFF7ED),
                inactiveIconColor: const Color(0xFFF97316),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GraduationVerificationScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({
    required this.title,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Semester History',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.82),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ArrowButton(
              icon: Icons.chevron_left_rounded,
              enabled: canGoPrevious,
              onTap: onPrevious,
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 132),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE9D5FF)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2CBF).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              enabled: canGoNext,
              onTap: onNext,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Swipe through previous semesters and view your synced timetable.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.34,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFFEDE9FE) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: enabled ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Icon(
              icon,
              color: enabled ? const Color(0xFF6D28D9) : const Color(0xFF9CA3AF),
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoStudentBanner extends StatelessWidget {
  const _DemoStudentBanner({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.science_outlined, size: 16, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Previewing test student $studentId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleStateMessage extends StatelessWidget {
  const _ScheduleStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9D5FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: const Color(0xFF7B2CBF), size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
