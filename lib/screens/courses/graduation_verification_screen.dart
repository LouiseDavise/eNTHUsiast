import 'package:flutter/material.dart';

import '../../models/graduation_verification_model.dart';
import 'widgets/graduation_category_card.dart';
import 'widgets/progress_summary_card.dart';

class GraduationVerificationScreen extends StatelessWidget {
  const GraduationVerificationScreen({super.key});

  static const List<GraduationCategory> dummyCategories = [
    GraduationCategory(
      title: 'Compulsory',
      earnedCredits: 12,
      requiredCredits: 30,
      records: [
        GraduationCourseRecord(
          title: 'Language Course',
          credits: 4,
          grade: 'A+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'College Chinese',
          credits: 2,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'English (1)',
          credits: 2,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'English (2)',
          credits: 2,
          grade: 'B+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Physical Education',
          credits: 0,
          grade: 'P',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Student Service',
          credits: 0,
          grade: 'P',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Conduct',
          credits: 0,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'History and Culture',
          credits: 2,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'General Education: Humanities',
          credits: 2,
          grade: '',
          status: 'inProgress',
        ),
      ],
    ),

    GraduationCategory(
      title: 'Department Required',
      earnedCredits: 15,
      requiredCredits: 22,
      records: [
        GraduationCourseRecord(
          title: 'Introduction to Programming',
          credits: 3,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Data Structures',
          credits: 3,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Algorithm',
          credits: 3,
          grade: 'B+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Computer Networks',
          credits: 3,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Operating Systems',
          credits: 3,
          grade: 'B+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Compiler Design',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'Senior Project',
          credits: 4,
          grade: '',
          status: 'inProgress',
        ),
      ],
    ),

    GraduationCategory(
      title: 'Basic Core Elective',
      earnedCredits: 9,
      requiredCredits: 24,
      records: [
        GraduationCourseRecord(
          title: 'Calculus',
          credits: 3,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Linear Algebra',
          credits: 3,
          grade: 'B+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Probability',
          credits: 3,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Discrete Mathematics',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'Statistics',
          credits: 3,
          grade: '',
          status: 'notPassed',
        ),
      ],
    ),

    GraduationCategory(
      title: 'Elective Core',
      earnedCredits: 6,
      requiredCredits: 21,
      records: [
        GraduationCourseRecord(
          title: 'Software Studio',
          credits: 3,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Database Systems',
          credits: 3,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Web Programming',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'Mobile Application Development',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
      ],
    ),

    GraduationCategory(
      title: 'Professional Elective',
      earnedCredits: 12,
      requiredCredits: 30,
      records: [
        GraduationCourseRecord(
          title: 'Logic Design',
          credits: 3,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Artificial Intelligence',
          credits: 3,
          grade: 'A-',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Machine Learning',
          credits: 3,
          grade: 'B+',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Network Security',
          credits: 3,
          grade: 'A',
          status: 'passed',
        ),
        GraduationCourseRecord(
          title: 'Embedded Systems',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'Cloud Computing',
          credits: 3,
          grade: '',
          status: 'inProgress',
        ),
        GraduationCourseRecord(
          title: 'Computer Vision',
          credits: 3,
          grade: '',
          status: 'notPassed',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  const ProgressSummaryCard(
                    earnedCredits: 63,
                    totalCredits: 128,
                    semesterCredits: '6',
                    cumulativeGpa: '3.82',
                  ),

                  const SizedBox(height: 28),

                  ...dummyCategories.map(
                    (category) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: GraduationCategoryCard(category: category),
                      );
                    },
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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
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
                color: Color(0xFF94A3B8),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'GRADUATION VERIFICATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
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