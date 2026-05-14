import 'package:flutter/material.dart';

class PlannerEnrollCard extends StatelessWidget {
  final int courseCount;
  final int totalCredits;

  const PlannerEnrollCard({
    super.key,
    required this.courseCount,
    required this.totalCredits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF7E3291),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E3291).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to Enroll?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You have selected $courseCount courses totaling $totalCredits credits for the Fall 2026 semester.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE9D5FF),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7E3291),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'PROCEED TO REGISTRATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}