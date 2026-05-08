import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';
import '../utilities/schedule_data.dart';
import '../utilities/slot_label_helper.dart';
import 'course_card.dart';
import 'time_slot_cell.dart';
import 'grid_painter.dart';

/// Assembles the full timetable: header row, time column, grid lines, and
/// all course cards.
class TimetableGrid extends StatelessWidget {
  final List<CourseItem> schedule;
 
  static const double rowHeight = 56.0;
  static const double timeColWidth = 52.0;
  static const int colCount = 5;
  static const List<String> dayLabels = ['M', 'T', 'W', 'T', 'F'];
 
  const TimetableGrid({super.key, required this.schedule});
 
  @override
  Widget build(BuildContext context) {
    // LayoutBuilder at the top level gives every child the real available
    // width, so Expanded / column-width math always works correctly.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final double gridWidth = totalWidth - timeColWidth;
        final double colWidth = gridWidth / colCount;
        final int rowCount = timeSlots.length;
        final double gridHeight = rowCount * rowHeight;
 
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDayHeader(totalWidth, gridWidth),
            _buildBody(rowCount, gridHeight, gridWidth, colWidth),
          ],
        );
      },
    );
  }
 
  // ── Day-of-week header ─────────────────────────────────────────────────────
 
  Widget _buildDayHeader(double totalWidth, double gridWidth) {
    return SizedBox(
      width: totalWidth,
      child: Row(
        children: [
          SizedBox(width: timeColWidth),
          ...List.generate(colCount, (i) {
            return SizedBox(
              width: gridWidth / colCount,
              child: Center(
                child: Text(
                  dayLabels[i],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
 
  // ── Time column + grid area ────────────────────────────────────────────────
 
  Widget _buildBody(
      int rowCount, double gridHeight, double gridWidth, double colWidth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: fixed-width time labels
        SizedBox(
          width: timeColWidth,
          height: gridHeight,
          child: Column(
            children: List.generate(rowCount, (i) {
              return TimeSlotCell(
                label: slotLabel(i),
                startTime: timeSlots[i]['start']!,
                endTime: timeSlots[i]['end']!,
                height: rowHeight,
              );
            }),
          ),
        ),
 
        // Right: explicit width so Stack is always bounded
        SizedBox(
          width: gridWidth,
          height: gridHeight,
          child: Stack(
            children: [
              // Grid lines
              CustomPaint(
                size: Size(gridWidth, gridHeight),
                painter: TimetableGridPainter(
                  rowCount: rowCount,
                  colCount: colCount,
                  rowHeight: rowHeight,
                ),
              ),
              // Course cards
              ...schedule.map((c) => _positionedCard(c, colWidth)),
            ],
          ),
        ),
      ],
    );
  }
 
  // ── Positioned course card ─────────────────────────────────────────────────
 
  Widget _positionedCard(CourseItem c, double colWidth) {
    final double left = (c.day - 1) * colWidth + 2;
    final double top = c.startSlot * rowHeight + 2;
    final double width = colWidth - 4;
    final double height = c.duration * rowHeight - 4;
 
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: CourseCard(course: c),
    );
  }
}