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
            top: 4, // Increased slightly so it doesn't touch the top grid line
            right: 6, // Increased slightly to keep it away from the column border
            child: Text(
              startTime,
              style: const TextStyle(
                fontSize: 9, // Increased from 7 for mobile readability
                fontWeight: FontWeight.w600, // Adjusted from w500
                color: Color(0xFF94A3B8), // Unified with UI palette
              ),
            ),
          ),
          
          // Slot badge – vertically centered
          Positioned.fill(
            child: Center(
              child: Container(
                width: 24, // Increased from 18 to accommodate larger text
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9), // Unified light gray bg
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11, // Increased from 9
                      fontWeight: FontWeight.w700, // Reduced from w800
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // End time – bottom right
          Positioned(
            bottom: 4, // Increased slightly so it doesn't touch the bottom grid line
            right: 6,
            child: Text(
              endTime,
              style: const TextStyle(
                fontSize: 9, // Increased from 6 (size 6 is generally unreadable)
                fontWeight: FontWeight.w500, // Increased from w400
                color: Color(0xFFCBD5E1), // Kept slightly lighter than start time
              ),
            ),
          ),
        ],
      ),
    );
  }
}