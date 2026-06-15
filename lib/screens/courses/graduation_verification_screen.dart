import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/graduation_verification_model.dart';
import '../../providers/ccxp_data_provider.dart';
import '../../providers/language_provider.dart';
import 'widgets/graduation_category_card.dart';
import 'widgets/progress_summary_card.dart';

class GraduationVerificationScreen extends StatelessWidget {
  const GraduationVerificationScreen({super.key});

  Map<String, dynamic> _summaryFrom(Map<String, dynamic>? graduationData) {
    return graduationData?['summary'] as Map<String, dynamic>? ?? {};
  }

  List<GraduationCategory> _buildCategories(dynamic categoryData) {
    final categories = categoryData as List<dynamic>? ?? [];

    return categories.map((cat) {
      final records = (cat['records'] as List<dynamic>? ?? []).map((rec) {
        return GraduationCourseRecord(
          title: rec['title']?.toString() ?? '',
          credits: rec['credits'] is int
              ? rec['credits'] as int
              : int.tryParse('${rec['credits']}') ?? 0,
          grade: rec['grade']?.toString() ?? '',
          status: rec['status']?.toString() ?? '',
        );
      }).toList();

      return GraduationCategory(
        title: cat['title']?.toString() ?? '',
        earnedCredits: cat['earnedCredits'] is int
            ? cat['earnedCredits'] as int
            : int.tryParse('${cat['earnedCredits']}') ?? 0,
        requiredCredits: cat['requiredCredits'] is int
            ? cat['requiredCredits'] as int
            : int.tryParse('${cat['requiredCredits']}') ?? 0,
        records: records,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final graduationData = context.watch<CcxpDataProvider>().graduationData;
    final isChinese = LanguageScope.watch(context).isChinese;

    if (graduationData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            isChinese
                ? '畢業資料無法取得，請先登入。'
                : 'Graduation data is not available. Please login first.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final summary = _summaryFrom(graduationData);
    final categories = _buildCategories(graduationData['categories']);
    final int totalEarned = categories.fold(
      0,
      (sum, item) => sum + item.earnedCredits,
    );
    const int graduationRequirement = 128;
    final semesterCredits =
        summary['currentSemesterCourses']?.toString() ?? '0';
    final cumulativeGpa = summary['cumulativeGpa']?.toString() ?? '0.00';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(isChinese: isChinese),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  ProgressSummaryCard(
                    earnedCredits: totalEarned,
                    totalCredits: graduationRequirement,
                    semesterCredits: semesterCredits,
                    cumulativeGpa: cumulativeGpa,
                  ),
                  const SizedBox(height: 28),
                  ...categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: GraduationCategoryCard(category: category),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isChinese});

  final bool isChinese;

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
                color: Color(0xFF64748B),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EECS-GS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isChinese ? '畢業資格審查' : 'GRADUATION VERIFICATION',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
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