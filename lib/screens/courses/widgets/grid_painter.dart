import 'package:flutter/material.dart';

/// Paints solid grid lines — both column and row separators.
/// Matches the PlannerGridPainter style from the reference code.
class TimetableGridPainter extends CustomPainter {
  final double dayWidth;
  final double periodHeight;
  final int dayCount;
  final int periodCount;

  const TimetableGridPainter({
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

    // Vertical column lines (including outer borders)
    for (int i = 0; i <= dayCount; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal period lines (including outer borders)
    for (int i = 0; i <= periodCount; i++) {
      final y = i * periodHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TimetableGridPainter old) =>
      old.dayWidth != dayWidth ||
      old.periodHeight != periodHeight ||
      old.dayCount != dayCount ||
      old.periodCount != periodCount;
}