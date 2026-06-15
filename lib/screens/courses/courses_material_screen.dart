import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:enthusiast/providers/ccxp_data_provider.dart';
import '../../models/courses_material_model.dart';
import 'widgets/course_material_card.dart';
import 'widgets/material_week_card.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart'; // Added for language support

class CourseMaterialsScreen extends StatelessWidget {
  const CourseMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.watch(context); // Watch language
    final isChinese = language.isChinese;
    final currCourses = context.watch<CcxpDataProvider>().scheduleData;

    final courses = List.generate(currCourses.length, (idx) {
      final course = currCourses[idx];
      final materials = (course['materials'] as List?)?.map<MaterialItem>((m) {
            return MaterialItem(
              week: '',
              title: m['title'] ?? (isChinese ? '教材' : 'Material'),
              url: m['url'],
            );
          }).toList() ??
          [];

      return CourseMaterial(
        id: course['title'] as String? ?? '', // ← was: course['title']
        title: course['title'] as String? ?? '', // ← was: course['title']
        code: course['code'] as String? ?? '', // ← was: course['code']
        platform:
            course['platform'] as String? ?? '', // ← was: course['platform']
        teacher: course['teacher'] as String? ?? '', // ← was: course['teacher']
        updatedText: course['room'] as String? ?? '', // ← was: course['room']
        units: materials.isNotEmpty
            ? [
                CourseUnit(
                  title: isChinese ? '課程教材' : 'MATERIALS',
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
                  Text(
                    isChinese ? '課程教材' : 'Course Materials',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
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
                              isChinese: isChinese,
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
  final bool isChinese;

  const CourseMaterialDetailScreen({
    super.key,
    required this.course,
    this.courseUrl,
    required this.isChinese,
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
                                Text(
                                  isChinese ? '暫無教材' : 'No Materials Yet',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isChinese
                                      ? '前往課程頁面以獲取教材'
                                      : 'Visit the course page to access materials',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.open_in_new_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isChinese
                                            ? '前往課程頁面'
                                            : 'Go to Course Page',
                                        style: const TextStyle(
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
                              ...unit.materials.map((material) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: MaterialWeekCard(material: material),
                                );
                              }),
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

  const _Header({required this.course});

  @override
  Widget build(BuildContext context) {
    final isElearn = course.platform.toUpperCase() == 'ELEARN';
    return Row(
      children: [
        _CircleBackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            course.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isElearn ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8), // Softened from 6 to 8
          ),
          child: Text(
            course.platform.toUpperCase(),
            style: TextStyle(
              fontSize: 10, // Increased from 8
              fontWeight: FontWeight.w700, // Reduced from w900
              letterSpacing: 0.5, // Reduced from 0.8
              color:
                  isElearn ? const Color(0xFF9333EA) : const Color(0xFF2563EB),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitTitle extends StatelessWidget {
  final String title;
  const _UnitTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 3,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
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
    );
  }
}
