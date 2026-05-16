import 'package:flutter/material.dart';

import '../../models/courses_planner_model.dart';
import 'widgets/course_planner_card.dart';
import 'widgets/course_planner_detail_sheet.dart' as detail;
import 'widgets/course_planner_filter_sheet.dart';
import 'widgets/course_planner_schedule_grid.dart' as schedule;
import 'widgets/course_planned_course_card.dart';
import 'widgets/course_planner_enroll_card.dart';
import 'widgets/course_planner_ai_button.dart';
import 'widgets/course_planner_ai_chat_dialog.dart';
import 'services/course_planner_firestore_services.dart';

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

  Set<String> baoBaoRecommendedCourseIds = {};

  final List<PlannerCourse> plannedCourses = [];

  final CoursePlannerFirestoreService _courseService =
      CoursePlannerFirestoreService();

  List<PlannerCourse> allCourses = [];
  bool isLoadingCourses = true;
  String? courseLoadError;

  @override
  void initState() {
    super.initState();
    loadCoursesFromFirebase();
  }

  Future<void> loadCoursesFromFirebase() async {
    setState(() {
      isLoadingCourses = true;
      courseLoadError = null;
    });

    try {
      final courses = await _courseService.fetchCourses();

      if (!mounted) return;

      setState(() {
        allCourses = courses;
        isLoadingCourses = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        courseLoadError = error.toString();
        isLoadingCourses = false;
      });
    }
  }

  int get totalCredits {
    int total = 0;

    for (final course in plannedCourses) {
      total += course.credits;
    }

    return total;
  }

  List<PlannerCourse> get filteredCourses {
    final query = searchQuery.trim().toLowerCase();

    final result = allCourses.where((course) {
      final alreadyPlanned = plannedCourses.any(
        (plannedCourse) => plannedCourse.id == course.id,
      );

      final matchesSearch = query.isEmpty ||
          course.title.toLowerCase().contains(query) ||
          course.code.toLowerCase().contains(query) ||
          course.professor.toLowerCase().contains(query) ||
          course.department.toLowerCase().contains(query) ||
          course.type.toLowerCase().contains(query) ||
          course.slotCode.toLowerCase().contains(query) ||
          course.location.toLowerCase().contains(query);

      final matchesType =
          selectedType == 'ALL' || course.type.toUpperCase() == selectedType;

      final matchesCredits =
          selectedCredits == null || course.credits == selectedCredits;

      final matchesDepartment =
          selectedDepartment == 'All' || course.department == selectedDepartment;

      return !alreadyPlanned &&
          matchesSearch &&
          matchesType &&
          matchesCredits &&
          matchesDepartment;
    }).toList();

    result.sort((a, b) {
      final aRecommended = baoBaoRecommendedCourseIds.contains(a.id);
      final bRecommended = baoBaoRecommendedCourseIds.contains(b.id);

      if (aRecommended && !bRecommended) return -1;
      if (!aRecommended && bRecommended) return 1;

      return a.code.compareTo(b.code);
    });

    return result;
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

  Future<void> openBaoBaoChat() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) {
        return const CoursePlannerAiChatDialog();
      },
    );

    if (!mounted) return;

    if (result == null) {
      return;
    }

    Set<String> recommendedIds = {};

    if (result is List<String>) {
      recommendedIds = result.toSet();
    } else if (result is Map<String, dynamic>) {
      final ids = result['courseIds'] as List<dynamic>? ?? [];
      recommendedIds = ids.map((id) => id.toString()).toSet();
    }

    if (recommendedIds.isEmpty) {
      return;
    }

    setState(() {
      selectedTab = 0;
      searchQuery = '';
      selectedType = 'ALL';
      selectedCredits = null;
      selectedDepartment = 'All';
      baoBaoRecommendedCourseIds = recommendedIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = filteredCourses;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: CoursePlannerAiButton(
        onTap: openBaoBaoChat,
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
              child: isLoadingCourses
                  ? const _CourseLoadingView()
                  : courseLoadError != null
                      ? _CourseLoadErrorView(
                          error: courseLoadError!,
                          onRetry: loadCoursesFromFirebase,
                        )
                      : selectedTab == 0
                          ? _DiscoverView(
                              courses: courses,
                              searchQuery: searchQuery,
                              selectedType: selectedType,
                              selectedCredits: selectedCredits,
                              selectedDepartment: selectedDepartment,
                              recommendedCourseIds:
                                  baoBaoRecommendedCourseIds,
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
                color: Color(0xFF64748B),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Course Planner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalCredits',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: active
                      ? const Color(0xFF7E3291)
                      : const Color(0xFF94A3B8),
                ),
              ),
              if (badge > 0 && title == 'MY PLAN') ...[
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E3291),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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
  final Set<String> recommendedCourseIds;
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
    required this.recommendedCourseIds,
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
    final hasFilter = widget.selectedType != 'ALL' ||
        widget.selectedCredits != null ||
        widget.selectedDepartment != 'All';

    final hasSearch = widget.searchQuery.trim().isNotEmpty;

    final isSearchActive = hasSearch || hasFilter || isFocused;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
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
                    ? const Color(0xFF9333EA).withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.04),
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
                size: 22,
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
                      hintText: 'Search code, name, teacher...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                      size: 24,
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
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Color(0xFF7E3291),
            ),
            SizedBox(width: 8),
            Text(
              'RECOMMENDED FOR YOU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          ...widget.courses.map(
            (course) {
              final conflict = widget.hasConflict(course);
              final recommendedByBaoBao =
                  widget.recommendedCourseIds.contains(course.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PlannerCourseCard(
                  course: course,
                  hasConflict: conflict,
                  recommendedByBaoBao: recommendedByBaoBao,
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
            },
          ),
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
                  border: Border.all(
                    color: const Color(0xFFE9D5FF),
                    width: 3,
                  ),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF020617),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Search and add courses to start planning your\nacademic journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onBrowse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3291),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'BROWSE COURSES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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
              size: 16,
              color: Color(0xFF7E3291),
            ),
            SizedBox(width: 8),
            Text(
              'WEEKLY SCHEDULE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        schedule.PlannerScheduleGrid(
          courses: plannedCourses,
          onRemove: onRemove,
        ),
        const SizedBox(height: 32),
        const Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 16,
              color: Color(0xFF7E3291),
            ),
            SizedBox(width: 8),
            Text(
              'COURSE LIST',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
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

class _CourseLoadingView extends StatelessWidget {
  const _CourseLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF7E3291),
      ),
    );
  }
}

class _CourseLoadErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _CourseLoadErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFFF2D55),
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E3291),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}