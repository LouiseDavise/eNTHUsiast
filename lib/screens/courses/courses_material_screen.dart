import 'package:flutter/material.dart';

import '../../models/courses_material_model.dart';
import 'widgets/course_material_card.dart';
import 'widgets/material_week_card.dart';

class CourseMaterialsScreen extends StatelessWidget {
  const CourseMaterialsScreen({super.key});

  static const List<CourseMaterial> mockCourseMaterials = [
    CourseMaterial(
      id: 'logic_design',
      title: 'Logic Design',
      code: 'EECS 124510',
      platform: 'ELEARN',
      teacher: 'Louise Davise',
      updatedText: '2 DAYS AGO',
      units: [
        CourseUnit(
          title: 'UNIT 1: NUMBER SYSTEMS',
          materials: [
            MaterialItem(
              week: 'WEEK 1',
              title: 'Number Systems & Base Conversion',
            ),
            MaterialItem(
              week: 'WEEK 2',
              title: 'Boolean Algebra Fundamentals',
            ),
          ],
        ),
        CourseUnit(
          title: 'UNIT 2: LOGIC GATES',
          materials: [
            MaterialItem(
              week: 'WEEK 3',
              title: 'Combinational Logic Circuits',
            ),
            MaterialItem(
              week: 'WEEK 4',
              title: 'Standard Logic Gate Designs',
            ),
          ],
        ),
      ],
    ),
    CourseMaterial(
      id: 'probability',
      title: 'Probability',
      code: 'EECS 12411',
      platform: 'ELEARN',
      teacher: 'Wilbert Chen',
      updatedText: 'TODAY',
      units: [
        CourseUnit(
          title: 'UNIT 1: INTRODUCTION',
          materials: [
            MaterialItem(
              week: 'WEEK 1',
              title: 'Basic Probability Concepts',
            ),
            MaterialItem(
              week: 'WEEK 2',
              title: 'Conditional Probability',
            ),
          ],
        ),
      ],
    ),
    CourseMaterial(
      id: 'software_studio',
      title: 'Software Studio',
      code: 'CS 12345',
      platform: 'EECLASS',
      teacher: 'Wu Shane Lung',
      updatedText: '1 WEEK AGO',
      units: [
        CourseUnit(
          title: 'UNIT 1: FLUTTER BASICS',
          materials: [
            MaterialItem(
              week: 'WEEK 1',
              title: 'Flutter Project Structure',
            ),
            MaterialItem(
              week: 'WEEK 2',
              title: 'Stateful and Stateless Widgets',
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final courses = mockCourseMaterials;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Course Materials',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: courses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final course = courses[index];

                    return CourseMaterialCard(
                      course: course,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseMaterialDetailScreen(
                              course: course,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseMaterialDetailScreen extends StatelessWidget {
  final CourseMaterial course;

  const CourseMaterialDetailScreen({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(course: course),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: course.units.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 26),
                  itemBuilder: (context, index) {
                    final unit = course.units[index];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _UnitTitle(title: unit.title),
                        const SizedBox(height: 12),
                        ...unit.materials.map(
                          (material) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MaterialWeekCard(material: material),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CourseMaterial course;

  const _Header({
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    final isElearn = course.platform.toUpperCase() == 'ELEARN';

    return Row(
      children: [
        _CircleBackButton(
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            course.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isElearn
                ? const Color(0xFFDBEAFE)
                : const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            course.platform.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isElearn
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFF97316),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitTitle extends StatelessWidget {
  final String title;

  const _UnitTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 2,
          color: const Color(0xFFD8B4FE),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleBackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF94A3B8),
          size: 25,
        ),
      ),
    );
  }
}