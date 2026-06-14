import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/courses_planner_model.dart';
import 'services/course_planner_firestore_services.dart';
import 'services/bao_bao_memory_service.dart';
import 'widgets/course_planner_ai_button.dart';
import 'widgets/course_planner_ai_chat_dialog.dart';
import 'widgets/course_planner_card.dart';
import 'widgets/course_planner_detail_sheet.dart' as detail;
import 'widgets/course_planner_filter_sheet.dart';
import 'widgets/course_planner_schedule_grid.dart';

class CoursePlannerScreen extends StatefulWidget {
  const CoursePlannerScreen({super.key});

  @override
  State<CoursePlannerScreen> createState() => _CoursePlannerScreenState();
}

class _CoursePlannerScreenState extends State<CoursePlannerScreen> {
  static const String _baoBaoStarterPrompt =
     'Bao-Bao, automatically create a useful first starter recommendation. '
    'First check what data is available. '
    'If curriculum is available, prioritize exact missing curriculum requirements. '
    'If curriculum is missing, do not pretend this is a complete graduation plan. '
    'Instead, create a practical starter plan using graduation data, user preferences, student year, and real available courses. '
    'Choose fewer but higher-quality courses. '
    'Prefer courses that match the user career goal, target credit load, language preference, GE interests, and year level. '
    'Avoid completed courses, in-progress courses, duplicated course sections, schedule conflicts, and courses too advanced for the student year. '
    'Build a balanced starter set: career-related courses first, then useful core/basic courses if safe, then GE/language/filler courses only if needed. '
    'If curriculum is missing, clearly mention that uploading curriculum will make the plan more accurate.'
    'If my preferences say English Taught, only recommend English-taught courses unless there are no matching courses. '; 
  
  int selectedTab = 0;

  String searchQuery = '';
  String selectedType = 'ALL';
  String selectedDepartment = 'All';
  int? selectedCredits;

  Set<String> baoBaoRecommendedCourseIds = {};
  bool showBaoBaoRecommendationsOnly = false;
  String? baoBaoRecommendationMessage;
  Map<String, List<String>> baoBaoCourseReasons = {};
  List<String> baoBaoAgentTrace = [];

  final List<PlannerCourse> plannedCourses = [];

  final CoursePlannerFirestoreService _courseService =
      CoursePlannerFirestoreService();
  final BaoBaoMemoryService _baoBaoMemoryService = BaoBaoMemoryService();

  List<PlannerCourse> allCourses = [];
  bool isLoadingCourses = true;
  String? courseLoadError;

  bool isLoadingPlan = true;
  String? planLoadError;

  bool _checkingBaoBaoIntro = false;
  bool _baoBaoIntroDialogOpen = false;

  @override
  void initState() {
    super.initState();
    loadCoursesFromFirebase();
    loadSavedPlannedCourses();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowBaoBaoIntro();
    });
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



  DocumentReference<Map<String, dynamic>>? get _coursePlannerDocRef {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('ccxpUsers')
        .doc(user.uid)
        .collection('coursePlanner')
        .doc('myPlan');
  }

  CollectionReference<Map<String, dynamic>>? get _plannedCoursesRef {
    return _coursePlannerDocRef?.collection('plannedCourses');
  }

  Future<void> loadSavedPlannedCourses() async {
    setState(() {
      isLoadingPlan = true;
      planLoadError = null;
    });

    try {
      final plannedCoursesRef = _plannedCoursesRef;

      if (plannedCoursesRef == null) {
        if (!mounted) return;

        setState(() {
          plannedCourses.clear();
          isLoadingPlan = false;
        });

        return;
      }

      final snapshot = await plannedCoursesRef.orderBy('addedAt').get();

      final savedCourses = <PlannerCourse>[];

      for (final doc in snapshot.docs) {
        try {
          savedCourses.add(
            _plannerCourseFromPlanData(
              fallbackId: doc.id,
              data: doc.data(),
            ),
          );
        } catch (error) {
          debugPrint('Failed to parse saved planned course ${doc.id}: $error');
        }
      }

      if (!mounted) return;

      setState(() {
        plannedCourses
          ..clear()
          ..addAll(savedCourses);
        isLoadingPlan = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        planLoadError = error.toString();
        isLoadingPlan = false;
      });

      debugPrint('Failed to load saved planned courses: $error');
    }
  }

  Future<void> _savePlannedCourseToFirebase(PlannerCourse course) async {
    final plannedCoursesRef = _plannedCoursesRef;
    final coursePlannerDocRef = _coursePlannerDocRef;

    if (plannedCoursesRef == null || coursePlannerDocRef == null) {
      return;
    }

    await plannedCoursesRef.doc(_planDocId(course)).set(
      _plannedCourseToMap(course),
      SetOptions(merge: true),
    );

    await coursePlannerDocRef.set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
        'courseCount': plannedCourses.length,
        'totalCredits': totalCredits,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _deletePlannedCourseFromFirebase(PlannerCourse course) async {
    final plannedCoursesRef = _plannedCoursesRef;
    final coursePlannerDocRef = _coursePlannerDocRef;

    if (plannedCoursesRef == null || coursePlannerDocRef == null) {
      return;
    }

    await plannedCoursesRef.doc(_planDocId(course)).delete();

    await coursePlannerDocRef.set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
        'courseCount': plannedCourses.length,
        'totalCredits': totalCredits,
      },
      SetOptions(merge: true),
    );
  }

  String _planDocId(PlannerCourse course) {
    final rawId = course.id.trim().isNotEmpty ? course.id : course.code;

    return rawId.replaceAll('/', '_').replaceAll('\\', '_');
  }

  Map<String, dynamic> _plannedCourseToMap(PlannerCourse course) {
    return {
      'id': course.id,
      'code': course.code,
      'title': course.title,
      'professor': course.professor,
      'credits': course.credits,
      'type': course.type,
      'department': course.department,
      'limit': course.limit,
      'rating': course.rating,
      'reviews': course.reviews,
      'midtermDate': course.midtermDate,
      'finalDate': course.finalDate,
      'projectDate': course.projectDate,
      'grading': course.grading,
      'syllabus': course.syllabus,
      'timeSlot': course.timeSlot,
      'slotCode': course.slotCode,
      'location': course.location,
      'language': course.language,
      'day': course.day,
      'startSlot': course.startSlot,
      'duration': course.duration,
      'colorValue': course.color.value,
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PlannerCourse _plannerCourseFromPlanData({
    required String fallbackId,
    required Map<String, dynamic> data,
  }) {
    final id = _stringFromPlanData(data['id'], fallback: fallbackId);
    final code = _stringFromPlanData(data['code'], fallback: id);

    return PlannerCourse(
      id: id,
      code: code,
      title: _stringFromPlanData(data['title'], fallback: code),
      professor: _stringFromPlanData(data['professor'], fallback: 'TBA'),
      credits: _intFromPlanData(data['credits']),
      type: _stringFromPlanData(data['type'], fallback: 'ELECTIVE'),
      department: _stringFromPlanData(data['department'], fallback: 'UNKNOWN'),
      limit: _intFromPlanData(data['limit']),
      rating: _doubleFromPlanData(data['rating']),
      reviews: _intFromPlanData(data['reviews']),
      midtermDate: _stringFromPlanData(data['midtermDate'], fallback: 'TBA'),
      finalDate: _stringFromPlanData(data['finalDate'], fallback: 'TBA'),
      projectDate: _stringFromPlanData(data['projectDate'], fallback: 'TBA'),
      grading: _gradingFromPlanData(data['grading']),
      syllabus: _syllabusFromPlanData(data['syllabus']),
      timeSlot: _stringFromPlanData(data['timeSlot']),
      slotCode: _stringFromPlanData(data['slotCode']),
      location: _stringFromPlanData(data['location'], fallback: 'TBA'),
      language: _stringFromPlanData(data['language']),
      day: _intFromPlanData(data['day']),
      startSlot: _intFromPlanData(data['startSlot']),
      duration: _intFromPlanData(data['duration'], fallback: 1),
      color: Color(
        _intFromPlanData(
          data['colorValue'],
          fallback: 0xFF7E3291,
        ),
      ),
    );
  }

  String _stringFromPlanData(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int _intFromPlanData(dynamic value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  double _doubleFromPlanData(dynamic value, {double fallback = 0.0}) {
    if (value == null) {
      return fallback;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? fallback;
  }

  Map<String, int> _gradingFromPlanData(dynamic value) {
    if (value is! Map) {
      return const {};
    }

    final result = <String, int>{};

    value.forEach((key, score) {
      result[key.toString()] = _intFromPlanData(score);
    });

    return result;
  }

  List<String> _syllabusFromPlanData(dynamic value) {
    if (value is! Iterable) {
      return const [
        'Course information is loaded from your saved plan.',
      ];
    }

    final result = value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    if (result.isEmpty) {
      return const [
        'Course information is loaded from your saved plan.',
      ];
    }

    return result;
  }

  Future<void> _maybeShowBaoBaoIntro() async {
    if (_checkingBaoBaoIntro || _baoBaoIntroDialogOpen) {
      return;
    }

    _checkingBaoBaoIntro = true;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final ccxpUserRef = FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(user.uid);

      final snapshot = await ccxpUserRef.get();
      final data = snapshot.data();
      final introDone = data?['baoBaoIntroDone'] == true;

      if (introDone || !mounted) {
        return;
      }

      _baoBaoIntroDialogOpen = true;

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (_) {
          return const _BaoBaoIntroDialog();
        },
      );

      await ccxpUserRef.set(
        {
          'baoBaoIntroDone': true,
          'baoBaoIntroDoneAt': FieldValue.serverTimestamp(),
          'baoBaoIntroVersion': 1,
        },
        SetOptions(merge: true),
      );

      if (shouldContinue == true && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await openBaoBaoChat(initialPrompt: _baoBaoStarterPrompt,);
      }
    } catch (error) {
      debugPrint('Bao-Bao intro check failed: $error');
    } finally {
      _checkingBaoBaoIntro = false;
      _baoBaoIntroDialogOpen = false;
    }
  }

  int get totalCredits {
    int total = 0;

    for (final course in plannedCourses) {
      total += course.credits;
    }

    return total;
  }

  List<String> get departmentOptions {
    final departments = allCourses
        .map((course) => course.department.trim().toUpperCase())
        .where((department) => department.isNotEmpty)
        .where((department) => department != 'UNKNOWN')
        .toSet()
        .toList();

    departments.sort();

    return ['All', ...departments];
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
          course.location.toLowerCase().contains(query) ||
          course.language.toLowerCase().contains(query);

      final matchesType =
          selectedType == 'ALL' || course.type.toUpperCase() == selectedType;

      final matchesCredits =
          selectedCredits == null || course.credits == selectedCredits;

      final matchesDepartment = selectedDepartment == 'All' ||
          course.department.toUpperCase() == selectedDepartment.toUpperCase();

      final matchesBaoBaoRecommendation = !showBaoBaoRecommendationsOnly ||
          baoBaoRecommendedCourseIds.contains(course.id);

      return !alreadyPlanned &&
          matchesSearch &&
          matchesType &&
          matchesCredits &&
          matchesDepartment &&
          matchesBaoBaoRecommendation;
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

    final conflict = hasScheduleConflict(course);

    if (conflict) {
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

    _savePlannedCourseToFirebase(course).catchError((error) {
      if (!mounted) {
        return;
      }

      setState(() {
        plannedCourses.removeWhere((item) => item.id == course.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save ${course.title}. Please try again.',
          ),
          backgroundColor: const Color(0xFFFF2D55),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      debugPrint('Failed to save planned course: $error');
    });

    if (baoBaoRecommendedCourseIds.contains(course.id)) {
      _baoBaoMemoryService
          .rememberAcceptedCourse(
            course,
            reasons: baoBaoCourseReasons[course.id] ?? const <String>[],
          )
          .catchError((error) {
        debugPrint('Failed to save Bao-Bao accepted-course memory: $error');
      });
    }

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
    final wasBaoBaoRecommended = baoBaoRecommendedCourseIds.contains(course.id);

    setState(() {
      plannedCourses.removeWhere((item) => item.id == course.id);
    });

    _deletePlannedCourseFromFirebase(course).catchError((error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed locally, but Firebase delete failed for ${course.title}.',
          ),
          backgroundColor: const Color(0xFFFF2D55),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      debugPrint('Failed to delete planned course: $error');
    });

    if (wasBaoBaoRecommended) {
      _baoBaoMemoryService
          .rememberRejectedCourse(
            course,
            reason: 'User removed a Bao-Bao recommended course from My Plan.',
          )
          .catchError((error) {
        debugPrint('Failed to save Bao-Bao rejected-course memory: $error');
      });
    }
  }

  bool hasScheduleConflict(PlannerCourse course) {
    if (course.day == 0 || course.startSlot == 0) {
      return false;
    }

    for (final plannedCourse in plannedCourses) {
      if (plannedCourse.id == course.id) {
        continue;
      }

      if (plannedCourse.day == 0 || plannedCourse.startSlot == 0) {
        continue;
      }

      if (plannedCourse.day != course.day) {
        continue;
      }

      final plannedStart = plannedCourse.startSlot;
      final plannedEnd = plannedCourse.startSlot + plannedCourse.duration;

      final courseStart = course.startSlot;
      final courseEnd = course.startSlot + course.duration;

      if (plannedStart < courseEnd && courseStart < plannedEnd) {
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
          departmentOptions: departmentOptions,
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedType = result['type']?.toString() ?? 'ALL';
        selectedCredits = result['credits'] as int?;
        selectedDepartment = result['department']?.toString() ?? 'All';

        showBaoBaoRecommendationsOnly = false;
        baoBaoRecommendedCourseIds.clear();
        baoBaoRecommendationMessage = null;
        baoBaoCourseReasons.clear();
        baoBaoAgentTrace.clear();
      });
    }
  }

  void exitBaoBaoRecommendations() {
    setState(() {
      baoBaoRecommendedCourseIds.clear();
      showBaoBaoRecommendationsOnly = false;
      baoBaoRecommendationMessage = null;
      baoBaoCourseReasons.clear();
      baoBaoAgentTrace.clear();
      searchQuery = '';
      selectedType = 'ALL';
      selectedCredits = null;
      selectedDepartment = 'All';
    });
  }

  Future<void> openBaoBaoChat({
    String? initialPrompt,
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) {
        return CoursePlannerAiChatDialog(
          allCourses: allCourses,
          plannedCourses: plannedCourses,
          initialPrompt: initialPrompt,
        );
      },
    );

    if (!mounted) return;

    if (result == null) {
      return;
    }

    Set<String> recommendedIds = {};
    String? recommendationMessage;
    Map<String, List<String>> courseReasons = {};
    List<String> agentTrace = [];

    if (result is List<String>) {
      recommendedIds = result.toSet();
    } else if (result is Map<String, dynamic>) {
      final ids = result['courseIds'] as List<dynamic>? ?? [];
      recommendedIds = ids.map((id) => id.toString()).toSet();
      recommendationMessage = result['message']?.toString();
      courseReasons = _parseBaoBaoCourseReasons(result['courseReasons']);
      agentTrace = _parseBaoBaoAgentTrace(result['agentTrace']);
    }

    if (recommendedIds.isEmpty) {
      return;
    }

    _baoBaoMemoryService
        .rememberRecommendationSession(
          courseIds: recommendedIds.toList(),
          message: recommendationMessage,
        )
        .catchError((error) {
      debugPrint('Failed to save Bao-Bao recommendation-session memory: $error');
    });

    setState(() {
      selectedTab = 0;
      searchQuery = '';
      selectedType = 'ALL';
      selectedCredits = null;
      selectedDepartment = 'All';
      baoBaoRecommendedCourseIds = recommendedIds;
      showBaoBaoRecommendationsOnly = true;
      baoBaoRecommendationMessage = recommendationMessage;
      baoBaoCourseReasons = courseReasons;
      baoBaoAgentTrace = agentTrace;
    });
  }

  Map<String, List<String>> _parseBaoBaoCourseReasons(dynamic raw) {
    final parsed = <String, List<String>>{};

    if (raw is! Map) {
      return parsed;
    }

    raw.forEach((key, value) {
      final courseId = key.toString();
      if (courseId.trim().isEmpty) return;

      if (value is Iterable) {
        parsed[courseId] = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(5)
            .toList();
      } else if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          parsed[courseId] = [text];
        }
      }
    });

    return parsed;
  }

  List<String> _parseBaoBaoAgentTrace(dynamic raw) {
    if (raw is! Iterable) {
      return const [];
    }

    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(6)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final courses = filteredCourses;

    void handleSearchChanged(String value) {
      setState(() {
        searchQuery = value;

        if (value.trim().isNotEmpty) {
          showBaoBaoRecommendationsOnly = false;
          baoBaoRecommendedCourseIds.clear();
          baoBaoRecommendationMessage = null;
          baoBaoCourseReasons.clear();
          baoBaoAgentTrace.clear();
        }
      });
    }

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
            if (selectedTab == 0) ...[
              const SizedBox(height: 16),
              _PinnedDiscoverSearchBar(
                searchQuery: searchQuery,
                selectedType: selectedType,
                selectedCredits: selectedCredits,
                selectedDepartment: selectedDepartment,
                onSearchChanged: handleSearchChanged,
                onFilterTap: openFilter,
              ),
              const SizedBox(height: 18),
            ] else
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
                              showBaoBaoRecommendationsOnly:
                                  showBaoBaoRecommendationsOnly,
                              baoBaoRecommendationMessage:
                                  baoBaoRecommendationMessage,
                              baoBaoCourseReasons: baoBaoCourseReasons,
                              baoBaoAgentTrace: baoBaoAgentTrace,
                              onExitBaoBaoRecommendations:
                                  exitBaoBaoRecommendations,
                              onSearchChanged: handleSearchChanged,
                              onFilterTap: openFilter,
                              onCourseTap: openCourseDetail,
                              onAddCourse: addCourse,
                              hasConflict: hasScheduleConflict,
                            )
                          : isLoadingPlan
                              ? const _CourseLoadingView()
                              : planLoadError != null
                                  ? _CourseLoadErrorView(
                                      error: planLoadError!,
                                      onRetry: loadSavedPlannedCourses,
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

  const _Header({
    required this.totalCredits,
  });

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


class _PinnedDiscoverSearchBar extends StatefulWidget {
  final String searchQuery;
  final String selectedType;
  final String selectedDepartment;
  final int? selectedCredits;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;

  const _PinnedDiscoverSearchBar({
    required this.searchQuery,
    required this.selectedType,
    required this.selectedDepartment,
    required this.selectedCredits,
    required this.onSearchChanged,
    required this.onFilterTap,
  });

  @override
  State<_PinnedDiscoverSearchBar> createState() =>
      _PinnedDiscoverSearchBarState();
}

class _PinnedDiscoverSearchBarState extends State<_PinnedDiscoverSearchBar> {
  late final TextEditingController searchController;
  bool isFocused = false;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _PinnedDiscoverSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != searchController.text) {
      searchController.text = widget.searchQuery;
      searchController.selection = TextSelection.collapsed(
        offset: searchController.text.length,
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = widget.selectedType != 'ALL' ||
        widget.selectedCredits != null ||
        widget.selectedDepartment != 'All';

    final hasSearch = widget.searchQuery.trim().isNotEmpty;
    final isSearchActive = hasSearch || hasFilter || isFocused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedContainer(
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
                  controller: searchController,
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
    );
  }
}

class _DiscoverView extends StatefulWidget {
  final List<PlannerCourse> courses;
  final String searchQuery;
  final String selectedType;
  final String selectedDepartment;
  final Set<String> recommendedCourseIds;
  final bool showBaoBaoRecommendationsOnly;
  final String? baoBaoRecommendationMessage;
  final Map<String, List<String>> baoBaoCourseReasons;
  final List<String> baoBaoAgentTrace;
  final int? selectedCredits;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onExitBaoBaoRecommendations;
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
    required this.showBaoBaoRecommendationsOnly,
    required this.baoBaoRecommendationMessage,
    required this.baoBaoCourseReasons,
    required this.baoBaoAgentTrace,
    required this.onExitBaoBaoRecommendations,
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
  late final TextEditingController searchController;
  bool isFocused = false;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _DiscoverView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != searchController.text) {
      searchController.text = widget.searchQuery;
      searchController.selection = TextSelection.collapsed(
        offset: searchController.text.length,
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      children: [
        if (widget.showBaoBaoRecommendationsOnly) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFD8B4FE),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFF7E3291),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Showing Bao-Bao recommendations',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7E3291),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: widget.onExitBaoBaoRecommendations,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'SHOW ALL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: Color(0xFF7E3291),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (widget.showBaoBaoRecommendationsOnly &&
            widget.baoBaoRecommendationMessage != null) ...[
          _BaoBaoResultBubble(
            message: widget.baoBaoRecommendationMessage!,
          ),
          const SizedBox(height: 14),
        ],
        if (widget.showBaoBaoRecommendationsOnly &&
            (widget.baoBaoCourseReasons.isNotEmpty ||
                widget.baoBaoAgentTrace.isNotEmpty)) ...[
          _BaoBaoReasonPanel(
            courses: widget.courses,
            courseReasons: widget.baoBaoCourseReasons,
            agentTrace: widget.baoBaoAgentTrace,
          ),
          const SizedBox(height: 18),
        ],
        if (widget.showBaoBaoRecommendationsOnly) ...[
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFF7E3291),
              ),
              SizedBox(width: 8),
              Text(
                'RECOMMENDED BY BAO-BAO',
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
        ],
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

class _BaoBaoReasonPanel extends StatelessWidget {
  final List<PlannerCourse> courses;
  final Map<String, List<String>> courseReasons;
  final List<String> agentTrace;

  const _BaoBaoReasonPanel({
    required this.courses,
    required this.courseReasons,
    required this.agentTrace,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCourses = courses
        .where((course) => courseReasons.containsKey(course.id))
        .take(4)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E3291).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 18,
                color: Color(0xFF7E3291),
              ),
              SizedBox(width: 8),
              Text(
                'WHY BAO-BAO PICKED THESE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: Color(0xFF7E3291),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleCourses.isNotEmpty) ...[
            ...visibleCourses.map((course) {
              final reasons = courseReasons[course.id] ?? const <String>[];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BaoBaoCourseReasonRow(
                  course: course,
                  reasons: reasons,
                ),
              );
            }),
          ],
          if (agentTrace.isNotEmpty) ...[
            const SizedBox(height: 2),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(left: 2, bottom: 4),
              dense: true,
              title: const Text(
                'Agent steps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                ),
              ),
              children: agentTrace.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BaoBaoCourseReasonRow extends StatelessWidget {
  final PlannerCourse course;
  final List<String> reasons;

  const _BaoBaoCourseReasonRow({
    required this.course,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 7),
          ...reasons.take(3).map((reason) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Color(0xFF7E3291),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BaoBaoResultBubble extends StatefulWidget {
  final String message;

  const _BaoBaoResultBubble({
    required this.message,
  });

  @override
  State<_BaoBaoResultBubble> createState() => _BaoBaoResultBubbleState();
}

class _BaoBaoResultBubbleState extends State<_BaoBaoResultBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final floatY = -3 + (_controller.value * 6);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE9D5FF),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E3291).withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE9D5FF),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '🐼',
                      style: TextStyle(fontSize: 25),
                    ),
                  ),
                ),
                const Positioned(
                  right: -4,
                  top: -4,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: Color(0xFF9333EA),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
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
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3E8FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF7E3291),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your plan is empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Browse courses and add them to build your semester plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onBrowse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E3291),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'BROWSE COURSES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final scheduledCourses = plannedCourses.where((course) {
      final hasValidDay = course.day >= 1 && course.day <= 5;
      final hasDuration = course.duration > 0;
      final hasTimeText = course.slotCode.trim().isNotEmpty &&
          course.slotCode.trim().toLowerCase() != 'no time';

      return hasValidDay && hasDuration && hasTimeText;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFD8B4FE),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF7E3291),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${plannedCourses.length} courses selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7E3291),
                  ),
                ),
              ),
              Text(
                '$totalCredits credits',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7E3291),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'WEEKLY SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        PlannerScheduleGrid(
          courses: scheduledCourses,
          onRemove: onRemove,
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'SELECTED COURSES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        ...plannedCourses.map(
          (course) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlannedCourseTile(
              course: course,
              onRemove: () => onRemove(course),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlannedCourseTile extends StatelessWidget {
  final PlannerCourse course;
  final VoidCallback onRemove;

  const _PlannedCourseTile({
    required this.course,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF7E3291),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${course.credits} credits • ${course.slotCode.isEmpty ? 'No time' : course.slotCode}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFFF2D55),
            ),
          ),
        ],
      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFCDD7),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF2D55),
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Failed to load courses',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3291),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _BaoBaoIntroDialog extends StatefulWidget {
  const _BaoBaoIntroDialog();

  @override
  State<_BaoBaoIntroDialog> createState() => _BaoBaoIntroDialogState();
}

class _BaoBaoIntroDialogState extends State<_BaoBaoIntroDialog>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _sparkleController;

  int _introStep = 0;

  static const List<String> _introMessages = [
    'Hi, I’m Bao-Bao 🐼\n\nI’m your agentic course-planning panda inside eNTHUsiast.',
    'First, I read your uploaded curriculum 📚\n\nI check department required, basic core, core courses, professional courses, lab courses, GE, and language requirements.',
    'Then I check your graduation data ✅\n\nI remove courses you already completed or are taking, so I don’t recommend the same class again.',
    'I also look at your preferences ✨\n\nCareer goal, GE interest, language preference, target credits, and time window help me rank better courses for you.',
    'Finally, I search the real course list 🔎\n\nTell me what you need, then I’ll recommend real course cards you can add to your plan.',
  ];

  bool get _isLastStep => _introStep >= _introMessages.length - 1;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isLastStep) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _introStep++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withOpacity(0.30),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _floatController,
                      _pulseController,
                      _sparkleController,
                    ]),
                    builder: (context, _) {
                      final floatValue =
                          math.sin(_floatController.value * math.pi * 2) * 8;
                      final pulseValue = 1 + (_pulseController.value * 0.035);
                      final sparkleRotate =
                          _sparkleController.value * math.pi * 2;

                      return Transform.translate(
                        offset: Offset(0, floatValue),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.04, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _IntroSpeechBubble(
                                key: ValueKey(_introStep),
                                text: _introMessages[_introStep],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Transform.scale(
                                  scale: pulseValue,
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFF4E3FF),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF9333EA)
                                              .withOpacity(0.24),
                                          blurRadius: 26,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFFD8B4FE),
                                            width: 5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _isLastStep ? '🐼' : '🐼',
                                            style:
                                                const TextStyle(fontSize: 43),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -34,
                                  top: 2,
                                  child: Transform.rotate(
                                    angle: sparkleRotate,
                                    child: const Text(
                                      '✦',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Color(0xFF9333EA),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -28,
                                  bottom: 12,
                                  child: Transform.rotate(
                                    angle: -sparkleRotate,
                                    child: const Text(
                                      '✦',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: Color(0xFF9333EA),
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  right: -12,
                                  bottom: 22,
                                  child: Text(
                                    '✧',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFA855F7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _IntroStepDots(
                              count: _introMessages.length,
                              activeIndex: _introStep,
                            ),
                            const SizedBox(height: 18),
                            _TapToContinuePill(
                              onTap: _handleTap,
                              label: _isLastStep
                                  ? 'Start chatting with Bao-Bao'
                                  : 'Tap anywhere to continue',
                              icon: _isLastStep ? '✨' : '☝️',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroStepDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _IntroStepDots({
    required this.count,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF7E3291)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF7E3291).withOpacity(0.35),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}

class _IntroSpeechBubble extends StatelessWidget {
  final String text;

  const _IntroSpeechBubble({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE9C7FF),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
        ),
        ClipPath(
          clipper: _BubbleTailClipper(),
          child: Container(
            width: 44,
            height: 26,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _TapToContinuePill extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final String icon;

  const _TapToContinuePill({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7E3291),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
