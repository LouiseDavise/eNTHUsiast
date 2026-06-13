import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utilities/data.dart';
import 'utilities/models.dart';
import 'widgets/bulletin.dart';
import 'widgets/calendar.dart';
import 'widgets/upcoming.dart';
import 'widgets/tutorial.dart';

// Popups
import 'widgets/add_task_popup.dart';
import 'widgets/subtask_manager_popup.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Global State
  bool _isBulletinCollapsed = false;
  bool _showTutorial = false;
  bool _showFab = false;
  final ScrollController _scrollController = ScrollController();
  DateTime _currentDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 80;
      if (shouldShow != _showFab) {
        setState(() => _showFab = shouldShow);
      }
    });
    TutorialTargetRegistry.forceBulletinOpen = () {
      if (mounted && _isBulletinCollapsed) {
        setState(() {
          _isBulletinCollapsed = false;
        });
      }
    };
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('hasSeenTutorial') ?? false;

    if (!hasSeenTutorial) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  Future<void> _markTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenTutorial', true);
    setState(() {
      _showTutorial = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openAddTask() {
    showDialog(context: context, builder: (context) => const AddTaskPopup());
  }

  void _openSubtaskManager(AppEvent event) {
    final workingSubtasks = event.subtasks
        .map((s) => Subtask(id: s.id, text: s.text, completed: s.completed))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return SubtaskManagerPopup(
            event: event,
            subtasks: workingSubtasks,
            onToggle: (subId) {
              final sub = workingSubtasks.firstWhere((s) => s.id == subId);
              sub.completed = !sub.completed;
              setStateModal(() {});
            },
            onUpdate: () {
              setState(() {});
            },
            onAddSubtask: (newText) {
              workingSubtasks.add(
                Subtask(
                  id: 'st-${DateTime.now().millisecondsSinceEpoch}',
                  text: newText,
                  completed: false,
                ),
              );
              setStateModal(() {});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 16, bottom: 16),
        child: SizedBox(
          key: TutorialTargetRegistry.get('fab-button'),
          width: 56,
          height: 56,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isFabHovered = true),
            onExit: (_) => setState(() => _isFabHovered = false),
            child: AnimatedScale(
              scale: _isFabHovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: FloatingActionButton(
                onPressed: _openAddTask,
                backgroundColor: nthuPurple,
                elevation: _isFabHovered ? 12 : 8,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Header Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wb_sunny_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "eNTHUsiast",
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: nthuPurple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "115 SPRING SEMESTER",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: nthuPurple,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Tutorial Button inside the scroll view (Moves up/away with page scrolling)
                      MouseRegion(
                        onEnter: (_) =>
                            setState(() => _isTutorialShortcutHovered = true),
                        onExit: (_) =>
                            setState(() => _isTutorialShortcutHovered = false),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTutorial = true;
                            });
                          },
                          child: AnimatedScale(
                            scale: _isTutorialShortcutHovered ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      _isTutorialShortcutHovered ? 0.18 : 0.12,
                                    ),
                                    blurRadius: _isTutorialShortcutHovered
                                        ? 12
                                        : 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.question_mark_rounded,
                                color: nthuPurple,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Card 1: Bulletin Container Box
                Container(
                  child: BulletinWidget(
                    isCollapsed: _isBulletinCollapsed,
                    onToggleCollapse: () => setState(
                      () => _isBulletinCollapsed = !_isBulletinCollapsed,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Card 2: Calendar Container Box
                Container(
                  child: CalendarWidget(
                    currentDate: _currentDate,
                    selectedDate: _selectedDate,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = date;
                        _currentDate = date;
                      });
                    },
                    onNavigate: (newDate) {
                      setState(() {
                        _currentDate = newDate;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Card 3: Upcoming Tasks Container Box
                Container(
                  child: UpcomingTasksWidget(onTaskTap: _openSubtaskManager),
                ),
              ],
            ),

            Positioned(
              bottom: 32,
              right: 32,
              child: AnimatedSlide(
                offset: _showFab ? Offset.zero : const Offset(0, 0.3),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showFab ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showFab,
                    child: Container(
                      key: TutorialTargetRegistry.get('fab-button'),
                      child: FloatingActionButton(
                        onPressed: _openAddTask,
                        backgroundColor: nthuPurple,
                        elevation: 8,
                        shape: const CircleBorder(),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Interactive Dashboard Tour Overlay Layer
            if (_showTutorial)
              TutorialOverlay(
                onComplete: _markTutorialComplete,
                onSkip: _markTutorialComplete,
              ),
          ],
        ),
      ),
    );
  }
}
