import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../models/courses_model.dart';
import './widgets/timetable_grid.dart';
import './widgets/menu_square_button.dart';
import './widgets/menu_wide_button.dart';
import './courses_material_screen.dart';
import './graduation_verification_screen.dart';
import './courses_planner_screen.dart';

/// Main courses screen.
/// Displays the "115 Spring" timetable using [TimetableGrid].
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  Future<List<CourseItem>> _fetchSchedule() async {
    // Load the JSON string from assets
    final String response = await rootBundle.loadString('assets/schedule.json');
    final List<dynamic> data = json.decode(response);

    return data.map((item) {
      return CourseItem(
        title: item['title'],
        code: item['code'],
        day: item['day'],
        startSlot: item['startSlot'],
        duration: item['duration'],
        // Parse the "0xFF..." string into a real Flutter Color
        bg: Color(int.parse(item['bg'])),
        border: Color(int.parse(item['border'])),
        text: Color(int.parse(item['text'])),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────
              const Text(
                '115 Spring',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w800, // Reduced from w900, removed italic
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),

              // ── Timetable card ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<List<CourseItem>>(
                  future: _fetchSchedule(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 400,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No courses found."));
                    }

                    // Pass the parsed JSON data directly to your TimetableGrid
                    return TimetableGrid(schedule: snapshot.data!);
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Course Materials + Course Planner buttons ──────────────
              Row(
                children: [
                  Expanded(
                    child: MenuSquareButton(
                      title: 'Course\nMaterials',
                      icon: Icons.menu_book_rounded,
                      activeColor: const Color(0xFF7E22CE),
                      inactiveBgColor: const Color(0xFFF3E8FF),
                      inactiveIconColor: const Color(0xFF9333EA),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourseMaterialsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: MenuSquareButton(
                      title: 'Course\nPlanner',
                      icon: Icons.search_rounded,
                      activeColor: const Color(0xFF3B82F6),
                      inactiveBgColor: const Color(0xFFEFF6FF),
                      inactiveIconColor: const Color(0xFF2563EB),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CoursePlannerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Graduation Verification button ─────────────────────────
              MenuWideButton(
                title: 'Graduation Verification',
                subtitle: 'CHECK YOUR DEGREE PROGRESS',
                icon: Icons.school_outlined,
                activeColor: const Color(0xFFF97316),
                inactiveBgColor: const Color(0xFFFFF7ED),
                inactiveIconColor: const Color(0xFFF97316),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GraduationVerificationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }
}
