import 'package:flutter/material.dart';

class ProgressSummaryCard extends StatelessWidget {
  final int earnedCredits;
  final int totalCredits;
  final String semesterCredits;
  final String cumulativeGpa;

  const ProgressSummaryCard({
    super.key,
    required this.earnedCredits,
    required this.totalCredits,
    required this.semesterCredits,
    required this.cumulativeGpa,
  });

  @override
  Widget build(BuildContext context) {
    final progress = earnedCredits / totalCredits;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF7E3291),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E3291).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL PROGRESS',
                  style: TextStyle(
                    fontSize: 12, // Increased from 10
                    fontWeight: FontWeight.w700, // Reduced from w900
                    letterSpacing: 1.0, // Reduced from 2.0
                    color: Color(0xFFE9D5FF),
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$earnedCredits',
                style: const TextStyle(
                  fontSize: 42,
                  height: 1.0, // Adjusted from 0.9 for upright text
                  fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6), // Adjusted to align baseline
                child: Text(
                  '/ $totalCredits cr',
                  style: const TextStyle(
                    fontSize: 14, // Increased from 12
                    fontWeight: FontWeight.w600, // Reduced from w900
                    color: Color(0xFFD8B4FE),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              _SmallInfo(
                label: 'SEMESTER',
                value: semesterCredits,
                suffix: ' COURSE',
              ),
              const SizedBox(width: 32),
              _SmallInfo(
                label: 'CUM. GPA',
                value: cumulativeGpa,
                suffix: '',
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(1)}% COMPLETED',
                style: const TextStyle(
                  fontSize: 11, // Increased from 9
                  fontWeight: FontWeight.w700, // Reduced from w900
                  letterSpacing: 0.5, // Reduced from 0.6
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;

  const _SmallInfo({
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10, // Increased from 8
            fontWeight: FontWeight.w600, // Reduced from w900
            letterSpacing: 0.5, // Reduced from 1.0
            color: Color(0xFFD8B4FE),
          ),
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 18, // Increased from 16
                  fontWeight: FontWeight.w700, // Reduced from w900, removed italic
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 12, // Increased from 9
                  fontWeight: FontWeight.w600, // Reduced from w900
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}