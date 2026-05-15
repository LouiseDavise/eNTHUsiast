import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';

class PlannerScheduleGrid extends StatelessWidget {
  final List<PlannerCourse> courses;
  final ValueChanged<PlannerCourse>? onRemove;

  const PlannerScheduleGrid({
    super.key,
    required this.courses,
    this.onRemove,
  });

  static const List<String> days = ['MON', 'TUE', 'WED', 'THU', 'FRI'];

  static const List<_NthuPeriod> periods = [
    _NthuPeriod(label: '1', start: '08:00', end: '08:50'),
    _NthuPeriod(label: '2', start: '09:00', end: '09:50'),
    _NthuPeriod(label: '3', start: '10:10', end: '11:00'),
    _NthuPeriod(label: '4', start: '11:10', end: '12:00'),
    _NthuPeriod(label: 'n', start: '12:10', end: '13:00'),
    _NthuPeriod(label: '5', start: '13:20', end: '14:10'),
    _NthuPeriod(label: '6', start: '14:20', end: '15:10'),
    _NthuPeriod(label: '7', start: '15:30', end: '16:20'),
    _NthuPeriod(label: '8', start: '16:30', end: '17:20'),
    _NthuPeriod(label: '9', start: '17:30', end: '18:20'),
    _NthuPeriod(label: 'a', start: '18:30', end: '19:20'),
    _NthuPeriod(label: 'b', start: '19:30', end: '20:20'),
    _NthuPeriod(label: 'c', start: '20:30', end: '21:20'),
    _NthuPeriod(label: 'd', start: '21:30', end: '22:20'),
  ];

  @override
  Widget build(BuildContext context) {
    const double leftWidth = 66;
    const double headerHeight = 34;
    const double periodHeight = 64;
    const double padding = 12;

    final double gridHeight = periodHeight * periods.length;
    final double contentHeight = headerHeight + gridHeight;

    return Container(
      height: contentHeight + padding * 2,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth - leftWidth;
          final dayWidth = gridWidth / days.length;

          final courseLayouts = _buildCourseLayouts(courses);

          return SizedBox(
            height: contentHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: leftWidth,
                  top: 0,
                  width: gridWidth,
                  height: headerHeight,
                  child: Row(
                    children: days.map((day) {
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

                Positioned(
                  left: 0,
                  top: headerHeight,
                  width: leftWidth,
                  height: gridHeight,
                  child: Column(
                    children: periods.map((period) {
                      return SizedBox(
                        height: periodHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 32,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    period.start,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    period.end,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 26,
                              height: 20,
                              margin: const EdgeInsets.only(top: 16),
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
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                Positioned(
                  left: leftWidth,
                  top: headerHeight,
                  width: gridWidth,
                  height: gridHeight,
                  child: CustomPaint(
                    painter: _PlannerGridPainter(
                      dayWidth: dayWidth,
                      periodHeight: periodHeight,
                      dayCount: days.length,
                      periodCount: periods.length,
                    ),
                  ),
                ),

                ...courseLayouts.map((layout) {
                  final course = layout.course;

                  final baseLeft = leftWidth + (course.day - 1) * dayWidth;
                  final availableWidth = dayWidth - 10;

                  final blockWidth = layout.columnCount == 1
                      ? availableWidth
                      : (availableWidth - (layout.columnCount - 1) * 4) /
                          layout.columnCount;

                  final left =
                      baseLeft + 5 + layout.columnIndex * (blockWidth + 4);

                  final top =
                      headerHeight + course.startSlot * periodHeight + 5;

                  final height = course.duration * periodHeight - 10;

                  final hasConflict = layout.columnCount > 1;

                  return Positioned(
                    left: left,
                    top: top,
                    width: blockWidth,
                    height: height,
                    child: _CourseBlock(
                      course: course,
                      hasConflict: hasConflict,
                      onRemove: onRemove,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_CourseLayout> _buildCourseLayouts(List<PlannerCourse> courses) {
    final List<_CourseLayout> result = [];

    for (int day = 1; day <= 5; day++) {
      final dayCourses = courses.where((course) => course.day == day).toList()
        ..sort((a, b) {
          final startCompare = a.startSlot.compareTo(b.startSlot);
          if (startCompare != 0) return startCompare;

          final aEnd = a.startSlot + a.duration;
          final bEnd = b.startSlot + b.duration;
          return aEnd.compareTo(bEnd);
        });

      final visited = <PlannerCourse>{};

      for (final course in dayCourses) {
        if (visited.contains(course)) continue;

        final group = <PlannerCourse>[];
        final queue = <PlannerCourse>[course];
        visited.add(course);

        while (queue.isNotEmpty) {
          final current = queue.removeAt(0);
          group.add(current);

          for (final other in dayCourses) {
            if (visited.contains(other)) continue;

            final overlapsAnyInGroup = group.any(
              (groupCourse) => _isOverlapping(groupCourse, other),
            );

            final overlapsCurrent = _isOverlapping(current, other);

            if (overlapsAnyInGroup || overlapsCurrent) {
              visited.add(other);
              queue.add(other);
            }
          }
        }

        result.addAll(_layoutConflictGroup(group));
      }
    }

    return result;
  }

  List<_CourseLayout> _layoutConflictGroup(List<PlannerCourse> group) {
    if (group.length == 1) {
      return [
        _CourseLayout(
          course: group.first,
          columnIndex: 0,
          columnCount: 1,
        ),
      ];
    }

    final sortedGroup = [...group]
      ..sort((a, b) {
        final startCompare = a.startSlot.compareTo(b.startSlot);
        if (startCompare != 0) return startCompare;

        final aEnd = a.startSlot + a.duration;
        final bEnd = b.startSlot + b.duration;
        return aEnd.compareTo(bEnd);
      });

    final List<int> columnEndSlots = [];
    final Map<PlannerCourse, int> assignedColumns = {};

    for (final course in sortedGroup) {
      int? availableColumn;

      for (int i = 0; i < columnEndSlots.length; i++) {
        if (course.startSlot >= columnEndSlots[i]) {
          availableColumn = i;
          break;
        }
      }

      if (availableColumn == null) {
        columnEndSlots.add(course.startSlot + course.duration);
        assignedColumns[course] = columnEndSlots.length - 1;
      } else {
        columnEndSlots[availableColumn] = course.startSlot + course.duration;
        assignedColumns[course] = availableColumn;
      }
    }

    final columnCount = columnEndSlots.length;

    return sortedGroup.map((course) {
      return _CourseLayout(
        course: course,
        columnIndex: assignedColumns[course] ?? 0,
        columnCount: columnCount,
      );
    }).toList();
  }

  bool _isOverlapping(PlannerCourse a, PlannerCourse b) {
    if (a.day != b.day) return false;

    final aStart = a.startSlot;
    final aEnd = a.startSlot + a.duration;

    final bStart = b.startSlot;
    final bEnd = b.startSlot + b.duration;

    return aStart < bEnd && bStart < aEnd;
  }
}

class _CourseBlock extends StatelessWidget {
  final PlannerCourse course;
  final bool hasConflict;
  final ValueChanged<PlannerCourse>? onRemove;

  const _CourseBlock({
    required this.course,
    required this.hasConflict,
    required this.onRemove,
  });

  Color _softBackground(Color color) {
    return Color.alphaBlend(
      color.withValues(alpha: 0.12),
      Colors.white,
    );
  }

  Color _softBorder(Color color) {
    return color.withValues(alpha: 0.55);
  }

  Color _strongText(Color color) {
    return Color.alphaBlend(
      color.withValues(alpha: 0.85),
      Colors.black,
    );
  }

  String _shortLocation(String location) {
    if (location.contains(',')) {
      return location.split(',').last.trim();
    }

    return location;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < 80;
        final isNarrow = constraints.maxWidth < 42;

        final bgColor = _softBackground(course.color);
        final borderColor = hasConflict
            ? const Color(0xFFFF2D55)
            : _softBorder(course.color);
        final textColor = _strongText(course.color);

        final titleFontSize = isNarrow ? 6.6 : 7.4;
        final codeFontSize = isNarrow ? 6.2 : 6.8;
        final locationFontSize = isNarrow ? 5.6 : 6.2;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isNarrow ? 5 : 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: hasConflict ? 1.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasConflict
                      ? const Color(0xFFFF2D55).withValues(alpha: 0.12)
                      : course.color.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: isShort ? 18 : 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: isShort ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          course.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: codeFontSize,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: textColor.withValues(alpha: 0.78),
                          ),
                        ),
                      ),

                      if (!isShort) ...[
                        const SizedBox(height: 3),
                        Flexible(
                          child: Text(
                            _shortLocation(course.location),
                            maxLines: isNarrow ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: locationFontSize,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              color: textColor.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (hasConflict)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF2D55),
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () {
                      if (onRemove != null) {
                        onRemove!(course);
                      }
                    },
                    child: Container(
                      width: isNarrow ? 15 : 18,
                      height: isNarrow ? 15 : 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: isNarrow ? 9 : 12,
                        color: textColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourseLayout {
  final PlannerCourse course;
  final int columnIndex;
  final int columnCount;

  const _CourseLayout({
    required this.course,
    required this.columnIndex,
    required this.columnCount,
  });
}

class _NthuPeriod {
  final String label;
  final String start;
  final String end;

  const _NthuPeriod({
    required this.label,
    required this.start,
    required this.end,
  });
}

class _PlannerGridPainter extends CustomPainter {
  final double dayWidth;
  final double periodHeight;
  final int dayCount;
  final int periodCount;

  _PlannerGridPainter({
    required this.dayWidth,
    required this.periodHeight,
    required this.dayCount,
    required this.periodCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    for (int i = 0; i <= dayCount; i++) {
      final x = i * dayWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (int i = 0; i <= periodCount; i++) {
      final y = i * periodHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlannerGridPainter oldDelegate) {
    return oldDelegate.dayWidth != dayWidth ||
        oldDelegate.periodHeight != periodHeight ||
        oldDelegate.dayCount != dayCount ||
        oldDelegate.periodCount != periodCount;
  }
}