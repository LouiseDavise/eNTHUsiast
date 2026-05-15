import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';
import '../utilities/schedule_data.dart';
import 'course_card.dart';
import 'grid_painter.dart';

// ── Period definition ─────────────────────────────────────────────────────────

class _Period {
  final String label;
  final String start;
  final String end;

  const _Period({required this.label, required this.start, required this.end});
}

// ── TimetableGrid ─────────────────────────────────────────────────────────────

/// Full-width timetable grid rendered via a single Stack of Positioned widgets.
/// Layout mirrors the PlannerScheduleGrid pattern for predictable sizing.
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

  const TimetableGrid({super.key, required this.schedule});

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
              // ── Day header ─────────────────────────────────────────────
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
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Time labels column ─────────────────────────────────────
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
                          // Start time – top left
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
                          // End time – bottom left
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
                          // Period badge – vertically centered, right side
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

              // ── Grid lines ─────────────────────────────────────────────
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

              // ── Course cards ───────────────────────────────────────────
              ...schedule.map((c) {
                final double left =
                    _leftWidth + (c.day - 1) * dayWidth + 5;
                final double top =
                    _headerHeight + c.startSlot * _periodHeight + 5;
                final double width = dayWidth - 10;
                final double height = c.duration * _periodHeight - 10;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: CourseCard(course: c),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}