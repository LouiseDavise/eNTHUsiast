import 'package:flutter/material.dart';

/// Displays a single time-slot row in the left time column:
/// start time (top), numbered/lettered badge (center), end time (bottom).
class TimeSlotCell extends StatelessWidget {
  final String label;
  final String startTime;
  final String endTime;
  final double height;

  const TimeSlotCell({
    super.key,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Start time – top right
          Positioned(
            top: 2,
            right: 4,
            child: Text(
              startTime,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          // Slot badge – vertically centered
          Positioned.fill(
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // End time – bottom right
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              endTime,
              style: const TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w400,
                color: Color(0xFFD1D5DB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}