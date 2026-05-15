import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/graduation_verification_model.dart';
import 'widgets/graduation_category_card.dart';
import 'widgets/progress_summary_card.dart';

class GraduationVerificationScreen extends StatelessWidget {
  const GraduationVerificationScreen({super.key});

  Future<List<GraduationCategory>> _loadGraduationData() async {
    final String response = await rootBundle.loadString(
      'assets/graduation_data.json',
    );
    final List<dynamic> data = json.decode(response);

    return data
        .map(
          (cat) => GraduationCategory(
            title: cat['title'],
            earnedCredits: cat['earnedCredits'],
            requiredCredits: cat['requiredCredits'],
            records: (cat['records'] as List)
                .map(
                  (rec) => GraduationCourseRecord(
                    title: rec['title'],
                    credits: rec['credits'],
                    grade: rec['grade'],
                    status: rec['status'],
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: FutureBuilder<List<GraduationCategory>>(
                future: _loadGraduationData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final categories = snapshot.data ?? [];

                  // Calculate dynamic totals from your JSON
                  int totalEarned = categories.fold(
                    0,
                    (sum, item) => sum + item.earnedCredits,
                  );

                  // Example: Count how many distinct courses are "inProgress"
                  int inProgressCount = categories.fold(
                    0,
                    (sum, cat) =>
                        sum +
                        cat.records
                            .where((r) => r.status == 'inProgress')
                            .length,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      ProgressSummaryCard(
                        earnedCredits: totalEarned,
                        totalCredits: 128, // Your graduation target
                        semesterCredits: inProgressCount
                            .toString(), // Current load
                        cumulativeGpa:
                            '3.82',
                      ),
                      const SizedBox(height: 28),
                      ...categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: GraduationCategoryCard(category: category),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(
                  0xFF64748B,
                ), // Darkened slightly for better contrast
                size: 26,
              ),
            ),
          ),

          const SizedBox(width: 14),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EECS-GS',
                style: TextStyle(
                  fontSize: 22, // Increased from 18
                  fontWeight:
                      FontWeight.w800, // Reduced from w900, removed italic
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'GRADUATION VERIFICATION',
                style: TextStyle(
                  fontSize: 11, // Increased from 9
                  fontWeight: FontWeight.w700, // Reduced from w900
                  letterSpacing: 1.0, // Reduced from 2.0
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
