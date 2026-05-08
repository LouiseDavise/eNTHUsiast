import 'package:flutter/material.dart';

/// Paints the background grid (solid column separators, dashed row separators).
class TimetableGridPainter extends CustomPainter {
  final int rowCount;
  final int colCount;
  final double rowHeight;

  const TimetableGridPainter({
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final solidPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;

    final dashedPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;

    // Outer borders
    canvas.drawLine(Offset.zero, Offset(size.width, 0), solidPaint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), solidPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), solidPaint);

    // Horizontal dashed row lines
    for (int i = 1; i <= rowCount; i++) {
      final y = i * rowHeight;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), dashedPaint);
    }

    // Vertical solid column lines
    for (int i = 1; i < colCount; i++) {
      final x = (i / colCount) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), solidPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    final double totalLength =
        (end.dx - start.dx).abs() + (end.dy - start.dy).abs();
    final Offset direction = Offset(
      (end.dx - start.dx) / totalLength,
      (end.dy - start.dy) / totalLength,
    );
    double distance = 0;
    while (distance < totalLength) {
      final Offset a = start + direction * distance;
      final Offset b =
          start + direction * (distance + dashWidth).clamp(0, totalLength);
      canvas.drawLine(a, b, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant TimetableGridPainter old) =>
      old.rowCount != rowCount ||
      old.colCount != colCount ||
      old.rowHeight != rowHeight;
}