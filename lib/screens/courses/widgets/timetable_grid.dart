import 'package:flutter/material.dart';

import '../../../models/courses_model.dart';
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
  const _TimetableCourseCard({required this.course});

  final CourseItem course;

  Color _textColorFromBorder(Color border) {
    final hsl = HSLColor.fromColor(border);
    return hsl
        .withSaturation((hsl.saturation + 0.12).clamp(0.35, 0.72).toDouble())
        .withLightness(0.30)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final background = Color.alphaBlend(
      course.bg.withValues(alpha: 0.08),
      Colors.white,
    );
    final borderColor = course.border.withValues(alpha: 0.82);
    final primaryTextColor = _textColorFromBorder(course.border);
    final secondaryTextColor = primaryTextColor.withValues(alpha: 0.76);

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTiny = constraints.maxHeight < 48;
                final isShort = constraints.maxHeight < 66;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: isTiny ? 3 : 6,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: (constraints.maxWidth - 14).clamp(40, 220),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              course.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTiny
                                    ? 9.0
                                    : isShort
                                        ? 9.8
                                        : 11.0,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                                height: 1.12,
                                letterSpacing: -0.08,
                              ),
                              maxLines: isTiny
                                  ? 1
                                  : isShort
                                      ? 1
                                      : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isTiny && course.timeRange.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                course.timeRange,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isShort ? 8.2 : 8.8,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryTextColor,
                                  height: 1.05,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (!isShort && course.room.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                course.room,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 7.8,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryTextColor.withValues(alpha: 0.86),
                                  height: 1.05,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCourseDetails(BuildContext context) {
    final borderColor = course.border.withValues(alpha: 0.82);
    final primaryTextColor = _textColorFromBorder(course.border);
    final background = Color.alphaBlend(
      course.bg.withValues(alpha: 0.14),
      Colors.white,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: primaryTextColor),
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
