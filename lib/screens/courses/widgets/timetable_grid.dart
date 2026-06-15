import 'package:flutter/material.dart';

import '../../../models/courses_model.dart';
import 'course_timetable_detail_sheet.dart';
import 'grid_painter.dart';

class _Period {
  final String label;
  final String start;
  final String end;

  const _Period({
    required this.label,
    required this.start,
    required this.end,
  });
}

class TimetableGrid extends StatelessWidget {
  final List<CourseItem> schedule;

  static const List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI'];

  static const List<_Period> _periods = [
    _Period(label: '1', start: '08:00', end: '08:50'),
    _Period(label: '2', start: '09:00', end: '09:50'),
    _Period(label: '3', start: '10:10', end: '11:00'),
    _Period(label: '4', start: '11:10', end: '12:00'),
    _Period(label: 'n', start: '12:10', end: '13:00'),
    _Period(label: '5', start: '13:20', end: '14:10'),
    _Period(label: '6', start: '14:20', end: '15:10'),
    _Period(label: '7', start: '15:30', end: '16:20'),
    _Period(label: '8', start: '16:30', end: '17:20'),
    _Period(label: '9', start: '17:30', end: '18:20'),
    _Period(label: 'a', start: '18:30', end: '19:20'),
    _Period(label: 'b', start: '19:30', end: '20:20'),
    _Period(label: 'c', start: '20:30', end: '21:20'),
    _Period(label: 'd', start: '21:30', end: '22:20'),
  ];

  static const double _leftWidth = 66;
  static const double _headerHeight = 34;
  static const double _periodHeight = 64;

  const TimetableGrid({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    final double gridHeight = _periodHeight * _periods.length;
    final double contentHeight = _headerHeight + gridHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double gridWidth = constraints.maxWidth - _leftWidth;
        final double dayWidth = gridWidth / _days.length;

        return SizedBox(
          height: contentHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: _leftWidth,
                top: 0,
                width: gridWidth,
                height: _headerHeight,
                child: Row(
                  children: _days.map((day) {
                    return SizedBox(
                      width: dayWidth,
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              Positioned(
                left: 0,
                top: _headerHeight,
                width: _leftWidth,
                height: gridHeight,
                child: Column(
                  children: _periods.map((period) {
                    return SizedBox(
                      height: _periodHeight,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            left: 0,
                            child: Text(
                              period.start,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 0,
                            child: Text(
                              period.end,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 4,
                            child: Center(
                              child: Container(
                                width: 26,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Center(
                                  child: Text(
                                    period.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              Positioned(
                left: _leftWidth,
                top: _headerHeight,
                width: gridWidth,
                height: gridHeight,
                child: CustomPaint(
                  painter: TimetableGridPainter(
                    dayWidth: dayWidth,
                    periodHeight: _periodHeight,
                    dayCount: _days.length,
                    periodCount: _periods.length,
                  ),
                ),
              ),

              ...schedule.map((course) {
                final double left =
                    _leftWidth + (course.day - 1) * dayWidth + 5;
                final double top =
                    _headerHeight + course.startSlot * _periodHeight + 5;
                final double width = dayWidth - 10;
                final double height = course.duration * _periodHeight - 10;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: _TimetableCourseCard(course: course),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _TimetableCourseCard extends StatelessWidget {
  final CourseItem course;

  const _TimetableCourseCard({
    required this.course,
  });

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CourseTimetableDetailSheet(course: course);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String timeText = course.timeText?.trim().isNotEmpty == true
        ? course.timeText!.trim()
        : 'Time N/A';

    final String locationText = course.location?.trim().isNotEmpty == true
        ? course.location!.trim()
        : '';

    final bool showLocation = course.duration >= 2 && locationText.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: course.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: course.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: course.text.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                course.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.8,
                  fontWeight: FontWeight.w900,
                  color: course.text,
                  height: 1.12,
                ),
                maxLines: course.duration >= 2 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              timeText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7.8,
                fontWeight: FontWeight.w800,
                color: course.text.withValues(alpha: 0.78),
                height: 1.05,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            if (showLocation) ...[
              const SizedBox(height: 2),
              Text(
                locationText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7.3,
                  fontWeight: FontWeight.w700,
                  color: course.text.withValues(alpha: 0.66),
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
