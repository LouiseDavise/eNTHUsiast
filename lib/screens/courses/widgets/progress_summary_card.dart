import 'package:flutter/material.dart';
import '../../../providers/language_provider.dart'; // Added import

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
    final language = LanguageScope.watch(context);
    final isChinese = language.isChinese;
    final progress = totalCredits > 0 ? earnedCredits / totalCredits : 0.0;

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
              Expanded(
                child: Text(
                  isChinese ? '總體進度' : 'TOTAL PROGRESS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
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
                child: const Icon(Icons.school_outlined, color: Colors.white, size: 25),
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
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  isChinese ? '/ $totalCredits 學分' : '/ $totalCredits cr',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                label: isChinese ? '本學期' : 'SEMESTER',
                value: semesterCredits,
                suffix: isChinese ? ' 門課' : ' COURSE',
              ),
              const SizedBox(width: 32),
              _SmallInfo(
                label: isChinese ? '累計 GPA' : 'CUM. GPA',
                value: cumulativeGpa,
                suffix: '',
              ),
              const Spacer(),
              Text(
                isChinese 
                    ? '${(progress * 100).toStringAsFixed(1)}% 已完成' 
                    : '${(progress * 100).toStringAsFixed(1)}% COMPLETED',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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