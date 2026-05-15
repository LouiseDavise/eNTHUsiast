import 'package:flutter/material.dart';

import '../../models/courses_planner_model.dart';
import 'widgets/course_planner_card.dart';
import 'widgets/course_planner_detail_sheet.dart' as detail;
import 'widgets/course_planner_filter_sheet.dart';
import 'widgets/course_planner_schedule_grid.dart' as schedule;
import 'widgets/course_planned_course_card.dart';
import 'widgets/course_planner_enroll_card.dart';
import 'widgets/course_planner_ai_button.dart';

class CoursePlannerScreen extends StatefulWidget {
  const CoursePlannerScreen({super.key});

  @override
  State<CoursePlannerScreen> createState() => _CoursePlannerScreenState();
}

class _CoursePlannerScreenState extends State<CoursePlannerScreen> {
  int selectedTab = 0; // 0 = Discover, 1 = My Plan

  String searchQuery = '';
  String selectedType = 'ALL';
  String selectedDepartment = 'All';
  int? selectedCredits;

  final List<PlannerCourse> plannedCourses = [];

  static const List<PlannerCourse> dummyCourses = [
    PlannerCourse(
      id: 'cs301',
      code: 'CS301',
      title: 'Machine Learning',
      professor: 'Lee Meng Jiao',
      credits: 2,
      type: 'CORE',
      department: 'Computer Science',
      limit: 60,
      rating: 5.0,
      reviews: 128,
      midtermDate: 'Oct 15',
      finalDate: 'Dec 20',
      projectDate: 'Dec 10',
      grading: {'Exams': 40, 'Projects': 40, 'Participation': 20},
      syllabus: [
        'Introduction & Overview',
        'Core Concepts & Theory',
        'Practical Applications',
      ],
      timeSlot: 'Mon 11:10 - 14:10',
      slotCode: 'M4M5',
      location: 'Building B, Room 402',
      day: 1,
      startSlot: 3,
      duration: 2,
      color: Color(0xFF14B8A6),
    ),

    PlannerCourse(
      id: 'cs210',
      code: 'CS210',
      title: 'Computer Architecture',
      professor: 'Huang Wei Cheng',
      credits: 2,
      type: 'CORE',
      department: 'Computer Science',
      limit: 60,
      rating: 4.8,
      reviews: 96,
      midtermDate: 'Oct 20',
      finalDate: 'Dec 18',
      projectDate: 'Dec 5',
      grading: {'Exams': 50, 'Projects': 30, 'Participation': 20},
      syllabus: ['CPU Basics', 'Memory System', 'Instruction Pipeline'],
      timeSlot: 'Tue 08:00 - 09:50',
      slotCode: 'T1T2',
      location: 'Engineering Building, Room 205',
      day: 2,
      startSlot: 0,
      duration: 2,
      color: Color(0xFF60A5FA),
    ),

    PlannerCourse(
      id: 'math202',
      code: 'MATH202',
      title: 'Probability',
      professor: 'Chen Yi Ting',
      credits: 3,
      type: 'ELECTIVE',
      department: 'Mathematics',
      limit: 80,
      rating: 4.6,
      reviews: 77,
      midtermDate: 'Oct 18',
      finalDate: 'Dec 22',
      projectDate: 'None',
      grading: {'Exams': 70, 'Homework': 20, 'Participation': 10},
      syllabus: ['Counting', 'Random Variables', 'Expected Value'],
      timeSlot: 'Tue 13:20 - 15:10',
      slotCode: 'T5T6',
      location: 'General Building, Room 301',
      day: 2,
      startSlot: 5,
      duration: 2,
      color: Color(0xFFA855F7),
    ),

    PlannerCourse(
      id: 'lang101',
      code: 'LANG101',
      title: 'College Chinese',
      professor: 'Lin Mei Hua',
      credits: 2,
      type: 'LANGUAGE',
      department: 'Language',
      limit: 40,
      rating: 4.7,
      reviews: 88,
      midtermDate: 'Oct 12',
      finalDate: 'Dec 16',
      projectDate: 'None',
      grading: {'Exams': 50, 'Homework': 30, 'Participation': 20},
      syllabus: ['Reading Practice', 'Writing Practice', 'Final Presentation'],
      timeSlot: 'Thu 13:20 - 15:10',
      slotCode: 'R5R6',
      location: 'Language Center, Room 101',
      day: 4,
      startSlot: 5,
      duration: 2,
      color: Color(0xFFFBBF24),
    ),

    PlannerCourse(
      id: 'ge101',
      code: 'GE101',
      title: 'Modern Society and Culture',
      professor: 'Wang Shu Fen',
      credits: 2,
      type: 'GE',
      department: 'General Education',
      limit: 100,
      rating: 4.5,
      reviews: 64,
      midtermDate: 'Oct 17',
      finalDate: 'Dec 19',
      projectDate: 'Nov 30',
      grading: {'Exams': 40, 'Projects': 40, 'Participation': 20},
      syllabus: [
        'Society and Identity',
        'Culture and Media',
        'Final Group Report',
      ],
      timeSlot: 'Fri 09:00 - 09:50',
      slotCode: 'F2',
      location: 'Humanities Building, Room 210',
      day: 5,
      startSlot: 1,
      duration: 1,
      color: Color(0xFFF472B6),
    ),

    PlannerCourse(
      id: 'pe101',
      code: 'PE101',
      title: 'Physical Education',
      professor: 'Chang Yu Ming',
      credits: 1,
      type: 'PE',
      department: 'Physical Education',
      limit: 45,
      rating: 4.9,
      reviews: 52,
      midtermDate: 'None',
      finalDate: 'Dec 15',
      projectDate: 'None',
      grading: {'Participation': 70, 'Skill Test': 30},
      syllabus: ['Basic Training', 'Team Practice', 'Final Skill Test'],
      timeSlot: 'Wed 16:30 - 17:20',
      slotCode: 'W8',
      location: 'Gymnasium Court 2',
      day: 3,
      startSlot: 8,
      duration: 1,
      color: Color(0xFF34D399),
    ),

    PlannerCourse(
      id: 'lab205',
      code: 'LAB205',
      title: 'Software Studio Lab',
      professor: 'Wu Shane Lung',
      credits: 1,
      type: 'LAB',
      department: 'Computer Science',
      limit: 30,
      rating: 4.8,
      reviews: 41,
      midtermDate: 'Oct 25',
      finalDate: 'Dec 23',
      projectDate: 'Dec 12',
      grading: {'Projects': 70, 'Participation': 30},
      syllabus: ['Flutter Basics', 'Firebase Integration', 'Final App Demo'],
      timeSlot: 'Mon 18:30 - 20:20',
      slotCode: 'MaMb',
      location: 'CS Lab, Room 501',
      day: 1,
      startSlot: 10,
      duration: 2,
      color: Color(0xFF22C55E),
    ),

    PlannerCourse(
      id: 'phy101',
      code: 'PHY101',
      title: 'General Physics',
      professor: 'Liu Kai Wen',
      credits: 3,
      type: 'CORE',
      department: 'Physics',
      limit: 90,
      rating: 4.4,
      reviews: 73,
      midtermDate: 'Oct 21',
      finalDate: 'Dec 21',
      projectDate: 'None',
      grading: {'Exams': 80, 'Homework': 20},
      syllabus: ['Motion', 'Energy', 'Electricity'],
      timeSlot: 'Tue 10:10 - 12:00',
      slotCode: 'T3T4',
      location: 'Science Building, Room 102',
      day: 2,
      startSlot: 2,
      duration: 2,
      color: Color(0xFF38BDF8),
    ),

    PlannerCourse(
      id: 'chem101',
      code: 'CHEM101',
      title: 'General Chemistry',
      professor: 'Tsai Chia Yu',
      credits: 3,
      type: 'CORE',
      department: 'Chemistry',
      limit: 85,
      rating: 4.3,
      reviews: 69,
      midtermDate: 'Oct 19',
      finalDate: 'Dec 18',
      projectDate: 'None',
      grading: {'Exams': 70, 'Lab': 20, 'Participation': 10},
      syllabus: [
        'Atoms and Molecules',
        'Chemical Bonds',
        'Reaction Principles',
      ],
      timeSlot: 'Thu 09:00 - 09:50',
      slotCode: 'R2',
      location: 'Chemistry Building, Room 304',
      day: 4,
      startSlot: 1,
      duration: 1,
      color: Color(0xFFFB7185),
    ),

    PlannerCourse(
      id: 'econ101',
      code: 'ECON101',
      title: 'Introduction to Economics',
      professor: 'Kao Ming Jie',
      credits: 3,
      type: 'ELECTIVE',
      department: 'Economics',
      limit: 120,
      rating: 4.6,
      reviews: 101,
      midtermDate: 'Oct 16',
      finalDate: 'Dec 17',
      projectDate: 'None',
      grading: {'Exams': 60, 'Homework': 20, 'Participation': 20},
      syllabus: ['Supply and Demand', 'Market Structure', 'Economic Policy'],
      timeSlot: 'Fri 13:20 - 15:10',
      slotCode: 'F5F6',
      location: 'Management Building, Room 201',
      day: 5,
      startSlot: 5,
      duration: 2,
      color: Color(0xFFF97316),
    ),

    PlannerCourse(
      id: 'psy101',
      code: 'PSY101',
      title: 'Introduction to Psychology',
      professor: 'Hsu Pei Ling',
      credits: 2,
      type: 'GE',
      department: 'Psychology',
      limit: 70,
      rating: 4.7,
      reviews: 84,
      midtermDate: 'Oct 14',
      finalDate: 'Dec 14',
      projectDate: 'Dec 1',
      grading: {'Exams': 50, 'Projects': 30, 'Participation': 20},
      syllabus: [
        'Mind and Behavior',
        'Learning and Memory',
        'Social Psychology',
      ],
      timeSlot: 'Tue 16:30 - 18:20',
      slotCode: 'T8T9',
      location: 'Social Science Building, Room 110',
      day: 2,
      startSlot: 8,
      duration: 2,
      color: Color(0xFFC084FC),
    ),

    PlannerCourse(
      id: 'hist101',
      code: 'HIST101',
      title: 'World History',
      professor: 'Chou Wen An',
      credits: 2,
      type: 'GE',
      department: 'History',
      limit: 75,
      rating: 4.2,
      reviews: 48,
      midtermDate: 'Oct 13',
      finalDate: 'Dec 13',
      projectDate: 'Nov 28',
      grading: {'Exams': 50, 'Projects': 30, 'Participation': 20},
      syllabus: ['Ancient Civilizations', 'Modern History', 'Globalization'],
      timeSlot: 'Mon 15:30 - 17:20',
      slotCode: 'M7M8',
      location: 'Humanities Building, Room 305',
      day: 1,
      startSlot: 7,
      duration: 2,
      color: Color(0xFF818CF8),
    ),

    PlannerCourse(
      id: 'soc101',
      code: 'SOC101',
      title: 'Sociology',
      professor: 'Yang Shu Hui',
      credits: 2,
      type: 'ELECTIVE',
      department: 'Sociology',
      limit: 65,
      rating: 4.3,
      reviews: 37,
      midtermDate: 'Oct 22',
      finalDate: 'Dec 20',
      projectDate: 'Dec 6',
      grading: {'Exams': 40, 'Projects': 40, 'Participation': 20},
      syllabus: [
        'Social Structure',
        'Groups and Institutions',
        'Social Change',
      ],
      timeSlot: 'Wed 13:20 - 15:10',
      slotCode: 'W5W6',
      location: 'Social Science Building, Room 208',
      day: 3,
      startSlot: 5,
      duration: 2,
      color: Color(0xFF2DD4BF),
    ),

    PlannerCourse(
      id: 'art101',
      code: 'ART101',
      title: 'Introduction to Arts',
      professor: 'Lai Yu Ting',
      credits: 1,
      type: 'ELECTIVE',
      department: 'Arts',
      limit: 50,
      rating: 4.8,
      reviews: 42,
      midtermDate: 'None',
      finalDate: 'Dec 11',
      projectDate: 'Dec 4',
      grading: {'Projects': 70, 'Participation': 30},
      syllabus: ['Visual Elements', 'Art Appreciation', 'Creative Project'],
      timeSlot: 'Fri 15:30 - 16:20',
      slotCode: 'F7',
      location: 'Arts Center, Room 102',
      day: 5,
      startSlot: 7,
      duration: 1,
      color: Color(0xFFFACC15),
    ),

    PlannerCourse(
      id: 'phil101',
      code: 'PHIL101',
      title: 'Introduction to Philosophy',
      professor: 'Teng Li Wei',
      credits: 4,
      type: 'GE',
      department: 'Philosophy',
      limit: 55,
      rating: 4.5,
      reviews: 58,
      midtermDate: 'Oct 23',
      finalDate: 'Dec 24',
      projectDate: 'None',
      grading: {'Exams': 60, 'Homework': 20, 'Participation': 20},
      syllabus: ['Logic and Argument', 'Ethics', 'Knowledge and Reality'],
      timeSlot: 'Thu 15:30 - 17:20',
      slotCode: 'R7R8',
      location: 'Humanities Building, Room 406',
      day: 4,
      startSlot: 7,
      duration: 2,
      color: Color(0xFF9CA3AF),
    ),

    PlannerCourse(
      id: 'cs230',
      code: 'CS230',
      title: 'Hardware Design & Lab',
      professor: 'Lee Meng Jiao',
      credits: 2,
      type: 'LAB',
      department: 'Computer Science',
      limit: 60,
      rating: 4.9,
      reviews: 112,
      midtermDate: 'Oct 16',
      finalDate: 'Dec 19',
      projectDate: 'Dec 8',
      grading: {'Exams': 35, 'Projects': 45, 'Participation': 20},
      syllabus: [
        'Digital Hardware Basics',
        'FPGA Design',
        'Hardware Lab Project',
      ],
      timeSlot: 'Mon 10:10 - 12:00',
      slotCode: 'M3M4',
      location: 'Engineering Building, Lab 303',
      day: 1,
      startSlot: 2,
      duration: 2,
      color: Color(0xFFA855F7),
    ),
  ];

  int get totalCredits {
    int total = 0;

    for (final course in plannedCourses) {
      total += course.credits;
    }

    return total;
  }

  List<PlannerCourse> get filteredCourses {
    final query = searchQuery.trim().toLowerCase();

    return dummyCourses.where((course) {
      final alreadyPlanned = plannedCourses.any(
        (plannedCourse) => plannedCourse.id == course.id,
      );

      final matchesSearch =
          query.isEmpty ||
          course.title.toLowerCase().contains(query) ||
          course.code.toLowerCase().contains(query) ||
          course.professor.toLowerCase().contains(query) ||
          course.department.toLowerCase().contains(query) ||
          course.type.toLowerCase().contains(query) ||
          course.slotCode.toLowerCase().contains(query);

      final matchesType =
          selectedType == 'ALL' || course.type.toUpperCase() == selectedType;

      final matchesCredits =
          selectedCredits == null || course.credits == selectedCredits;

      final matchesDepartment =
          selectedDepartment == 'All' ||
          course.department == selectedDepartment;

      return !alreadyPlanned &&
          matchesSearch &&
          matchesType &&
          matchesCredits &&
          matchesDepartment;
    }).toList();
  }

  void addCourse(PlannerCourse course) {
    final alreadyAdded = plannedCourses.any((item) => item.id == course.id);

    if (alreadyAdded) {
      return;
    }

    final hasConflict = hasScheduleConflict(course);

    if (hasConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${course.title} conflicts with your current plan.',
          ),
          backgroundColor: const Color(0xFFFF2D55),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      return;
    }

    setState(() {
      plannedCourses.add(course);

      // Do NOT switch tab automatically.
      // selectedTab = 1;  <-- remove this
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${course.title} added to My Plan.',
        ),
        backgroundColor: const Color(0xFF7E3291),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void removeCourse(PlannerCourse course) {
    setState(() {
      plannedCourses.removeWhere((item) => item.id == course.id);
    });
  }

  bool hasScheduleConflict(PlannerCourse course) {
    for (final plannedCourse in plannedCourses) {
      if (plannedCourse.id == course.id) {
        continue;
      }

      if (plannedCourse.day != course.day) {
        continue;
      }

      final plannedStart = plannedCourse.startSlot;
      final plannedEnd = plannedCourse.startSlot + plannedCourse.duration;

      final courseStart = course.startSlot;
      final courseEnd = course.startSlot + course.duration;

      final isOverlapping =
          plannedStart < courseEnd && courseStart < plannedEnd;

      if (isOverlapping) {
        return true;
      }
    }

    return false;
  }

  void openCourseDetail(PlannerCourse course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return detail.PlannerDetailSheet(
          course: course,
          onAdd: () {
            Navigator.pop(context);
            addCourse(course);
          },
        );
      },
    );
  }

  void openFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return PlannerFilterSheet(
          initialType: selectedType,
          initialCredits: selectedCredits,
          initialDepartment: selectedDepartment,
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedType = result['type'];
        selectedCredits = result['credits'];
        selectedDepartment = result['department'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = filteredCourses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: CoursePlannerAiButton(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) {
              return const _AiPlannerSheet();
            },
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(totalCredits: totalCredits),
            const SizedBox(height: 12),
            _Tabs(
              selectedTab: selectedTab,
              planCount: plannedCourses.length,
              onChanged: (index) {
                setState(() {
                  selectedTab = index;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: selectedTab == 0
                  ? _DiscoverView(
                      courses: courses,
                      searchQuery: searchQuery,
                      selectedType: selectedType,
                      selectedCredits: selectedCredits,
                      selectedDepartment: selectedDepartment,
                      onSearchChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      onFilterTap: openFilter,
                      onCourseTap: openCourseDetail,
                      onAddCourse: addCourse,
                      hasConflict: hasScheduleConflict,
                    )
                  : _MyPlanView(
                      plannedCourses: plannedCourses,
                      totalCredits: totalCredits,
                      onBrowse: () {
                        setState(() {
                          selectedTab = 0;
                        });
                      },
                      onRemove: removeCourse,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int totalCredits;

  const _Header({required this.totalCredits});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
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
          const Expanded(
            child: Text(
              'Course Planner',
              style: TextStyle(
                fontSize: 24, // Increased from 22
                fontWeight:
                    FontWeight.w800, // Reduced from w900, removed italic
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TOTAL CREDITS',
                style: TextStyle(
                  fontSize: 11, // Increased from 9
                  fontWeight: FontWeight.w700, // Reduced from w900
                  letterSpacing: 1.0, // Reduced from 1.5
                  color: Color(
                    0xFF94A3B8,
                  ), // Darkened slightly from CBD5E1 for legibility
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalCredits',
                style: const TextStyle(
                  fontSize: 22, // Increased from 20 to balance with main title
                  fontWeight: FontWeight.w800, // Reduced from w900
                  color: Color(0xFF7E3291),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int selectedTab;
  final int planCount;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.selectedTab,
    required this.planCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(4), // Inner padding for the "pill" effect
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(
          16,
        ), // Adjusted to 16 for a smooth pill
      ),
      child: Row(
        children: [
          _TabButton(
            title: 'DISCOVER',
            active: selectedTab == 0,
            onTap: () => onChanged(0),
          ),
          _TabButton(
            title: 'MY PLAN',
            active: selectedTab == 1,
            badge: planCount,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.active,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(
          14,
        ), // Smoothed from 13 to match outer
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42, // Increased from 38 for a better mobile tap target
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12, // Increased from 9 for readability
                  fontWeight: FontWeight.w700, // Reduced from w900
                  letterSpacing: 0.5, // Reduced from 1.3
                  color: active
                      ? const Color(0xFF7E3291)
                      : const Color(0xFF94A3B8),
                ),
              ),
              if (badge > 0 && title == 'MY PLAN') ...[
                const SizedBox(width: 8),
                Container(
                  width: 18, // Increased from 16 to fit larger text
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E3291),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 10, // Increased from 9
                        fontWeight: FontWeight.w700, // Reduced from w900
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverView extends StatefulWidget {
  final List<PlannerCourse> courses;
  final String searchQuery;
  final String selectedType;
  final String selectedDepartment;
  final int? selectedCredits;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final ValueChanged<PlannerCourse> onCourseTap;
  final ValueChanged<PlannerCourse> onAddCourse;
  final bool Function(PlannerCourse course) hasConflict;

  const _DiscoverView({
    required this.courses,
    required this.searchQuery,
    required this.selectedType,
    required this.selectedDepartment,
    required this.selectedCredits,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onCourseTap,
    required this.onAddCourse,
    required this.hasConflict,
  });

  @override
  State<_DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<_DiscoverView> {
  bool isFocused = false;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        widget.selectedType != 'ALL' ||
        widget.selectedCredits != null ||
        widget.selectedDepartment != 'All';

    final hasSearch = widget.searchQuery.trim().isNotEmpty;

    final isSearchActive = hasSearch || hasFilter || isFocused;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52, // Increased slightly from 50
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSearchActive
                  ? const Color(0xFFD8B4FE)
                  : const Color(0xFFE5E7EB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSearchActive
                    ? const Color(0xFF9333EA).withOpacity(0.16)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSearchActive ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: isSearchActive
                    ? const Color(0xFF9333EA)
                    : const Color(0xFFCBD5E1),
                size: 22, // Increased slightly
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Focus(
                  onFocusChange: (value) {
                    setState(() {
                      isFocused = value;
                    });
                  },
                  child: TextField(
                    onChanged: widget.onSearchChanged,
                    cursorColor: const Color(0xFF9333EA),
                    decoration: const InputDecoration(
                      hintText: 'Search code or name...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        fontSize: 14, // Increased from 13
                        fontWeight: FontWeight.w500, // Reduced from w700
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14, // Increased from 13
                      fontWeight: FontWeight.w600, // Reduced from w700
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: widget.onFilterTap,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      color: hasFilter
                          ? const Color(0xFF7E3291)
                          : const Color(0xFF94A3B8),
                      size: 24, // Increased slightly
                    ),
                    if (hasFilter)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E3291),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24), // Increased from 20

        const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16, // Increased slightly
              color: Color(0xFF7E3291),
            ),
            SizedBox(width: 8),
            Text(
              'RECOMMENDED FOR YOU',
              style: TextStyle(
                fontSize: 11, // Increased from 9
                fontWeight: FontWeight.w700, // Reduced from w900
                letterSpacing: 0.8, // Reduced from 1.6
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (widget.courses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Center(
              child: Text(
                'No courses found.',
                style: TextStyle(
                  fontSize: 14, // Increased from 13
                  fontWeight: FontWeight.w600, // Reduced from w800
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          ...widget.courses.map((course) {
            final conflict = widget.hasConflict(course);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlannerCourseCard(
                course: course,
                hasConflict: conflict,
                onTap: () => widget.onCourseTap(course),
                onAdd: conflict
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${course.title} conflicts with your current plan.',
                            ),
                            backgroundColor: const Color(0xFFFF2D55),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      }
                    : () => widget.onAddCourse(course),
              ),
            );
          }),
      ],
    );
  }
}

class _MyPlanView extends StatelessWidget {
  final List<PlannerCourse> plannedCourses;
  final int totalCredits;
  final VoidCallback onBrowse;
  final ValueChanged<PlannerCourse> onRemove;

  const _MyPlanView({
    required this.plannedCourses,
    required this.totalCredits,
    required this.onBrowse,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (plannedCourses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE9D5FF), width: 3),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFFB78BC4),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your plan is empty',
                style: TextStyle(
                  fontSize: 18, // Increased from 15
                  fontWeight: FontWeight.w800, // Reduced from w900
                  color: Color(0xFF020617),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Search and add courses to start planning your\nacademic journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, // Increased from 11
                  height: 1.5,
                  fontWeight: FontWeight.w500, // Reduced from w600
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onBrowse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3291),
                  foregroundColor: Colors.white,
                  elevation: 0, // Flattened to match modern UI
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // Unified to 16
                  ),
                ),
                child: const Text(
                  'BROWSE COURSES',
                  style: TextStyle(
                    fontSize: 14, // Increased from 10
                    fontWeight: FontWeight.w700, // Reduced from w900
                    letterSpacing: 0.5, // Reduced from 1
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      children: [
        const Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 16, // Increased slightly
              color: Color(0xFF7E3291),
            ),
            SizedBox(width: 8),
            Text(
              'WEEKLY SCHEDULE',
              style: TextStyle(
                fontSize: 11, // Increased from 9
                fontWeight: FontWeight.w700, // Reduced from w900
                letterSpacing: 0.8, // Reduced from 1.6
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Note: Using the alias or prefix if necessary for the custom grid
        schedule.PlannerScheduleGrid(
          courses: plannedCourses,
          onRemove: onRemove,
        ),
        const SizedBox(height: 32), // Increased from 24
        const Row(
          children: [
            Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF7E3291)),
            SizedBox(width: 8),
            Text(
              'COURSE LIST',
              style: TextStyle(
                fontSize: 11, // Increased from 9
                fontWeight: FontWeight.w700, // Reduced from w900
                letterSpacing: 0.8,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...plannedCourses.map((course) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PlannedCourseCard(
              course: course,
              onRemove: () => onRemove(course),
            ),
          );
        }),
        const SizedBox(height: 12),
        PlannerEnrollCard(
          courseCount: plannedCourses.length,
          totalCredits: totalCredits,
        ),
      ],
    );
  }
}

class _AiPlannerSheet extends StatelessWidget {
  const _AiPlannerSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF7E3291),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Ask Bao-Bao',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Need help planning your schedule?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF020617),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Bao-Bao can help recommend courses, check conflicts, and suggest a balanced course plan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE9D5FF),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Ask about your course plan...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Icon(
                  Icons.send_rounded,
                  color: Color(0xFF7E3291),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}