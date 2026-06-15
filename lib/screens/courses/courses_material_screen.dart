import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:enthusiast/providers/ccxp_data_provider.dart';
import '../../models/courses_material_model.dart';
import 'widgets/course_material_card.dart';
import 'widgets/material_week_card.dart';
import 'package:provider/provider.dart';

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
    final currCourses = context.watch<CcxpDataProvider>().scheduleData;
    final courses = List.generate(currCourses.length, (idx) {
      final course = currCourses[idx];
      final materials = (course['materials'] as List?)?.map<MaterialItem>((m) {
            return MaterialItem(
              week: '',
              title: m['title'] ?? 'Material',
              url: m['url'],
            );
          }).toList() ??
          [];

      return CourseMaterial(
        id: course['title'],
        title: course['title'],
        code: course['code'],
        platform: course['platform'],
        teacher: course['teacher'],
        updatedText: course['room'],
        units: materials.isNotEmpty
            ? [
                CourseUnit(
                  title: 'MATERIALS',
                  materials: materials,
                )
              ]
            : [],
      );
    });

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
                      fontSize: 24, // Increased from 22
                      fontWeight:
                          FontWeight.w800, // Reduced from w900, removed italic
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
                    final rawCourse = currCourses[index];

                    return CourseMaterialCard(
                      course: course,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseMaterialDetailScreen(
                              course: course,
                              courseUrl: rawCourse['url'],
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
  final String? courseUrl;

  const CourseMaterialDetailScreen({
    super.key,
    required this.course,
    this.courseUrl,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNoMaterials = course.units.isEmpty;

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
                child: hasNoMaterials
                    ? Center(
                        child: GestureDetector(
                          onTap: courseUrl != null
                              ? () => _launchUrl(courseUrl!)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: const Icon(
                                    Icons.link_rounded,
                                    size: 40,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'No Materials Yet',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Visit the course page to access materials',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Go to Course Page',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
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
              fontSize: 24, // Increased from 22
              fontWeight: FontWeight.w800, // Reduced from w900, removed italic
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 10), // Slightly increased spacing
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 5), // Increased vertical padding
          decoration: BoxDecoration(
            color: isElearn ? const Color(0xFFDBEAFE) : const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(8), // Softened from 6 to 8
          ),
          child: Text(
            course.platform.toUpperCase(),
            style: TextStyle(
              fontSize: 10, // Increased from 8
              fontWeight: FontWeight.w700, // Reduced from w900
              letterSpacing: 0.5, // Reduced from 0.8
              color:
                  isElearn ? const Color(0xFF2563EB) : const Color(0xFFF97316),
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
          height: 3, // Slightly thicker line to match larger text
          decoration: BoxDecoration(
            color: const Color(0xFFD8B4FE),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12, // Increased from 10
              fontWeight: FontWeight.w700, // Reduced from w900
              letterSpacing: 1.0, // Reduced from 2.0
              color: Color(
                  0xFF64748B), // Slightly darker gray for better legibility
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
        width: 38, // Slightly increased from 36
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF64748B), // Darkened slightly from 94A3B8
          size: 26,
        ),
      ),
    );
  }
}
