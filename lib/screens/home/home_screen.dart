import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utilities/data.dart';
import 'utilities/models.dart';
import 'widgets/bulletin.dart';
import 'widgets/calendar.dart';
import 'widgets/upcoming.dart';
import 'widgets/tutorial.dart';

// Popups
import 'widgets/add_task_popup.dart';
import 'widgets/day_details_popup.dart';
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
  DateTime _currentDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  List<String> _completedTaskIds = [];
  List<AppEvent> _customEvents = [];
  Map<String, List<Subtask>> _subtasksMap = Map.from(initialSubtasksMap);

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
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

  // Add this new method to mark it as complete
  Future<void> _markTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenTutorial', true);
    setState(() {
      _showTutorial = false;
    });
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  List<AppEvent> get _allUpcomingEvents {
    List<AppEvent> items = [];

    initialCalendarEvents.forEach((dateKey, events) {
      for (var event in events) {
        if (event.type != 'Lecture' && event.type != 'TODO') {
          items.add(event);
        }
      }
    });

    items.addAll(_customEvents);

    return items.map((event) {
      final subs = _subtasksMap[event.id] ?? [];
      int currentProgress = event.progress;
      if (subs.isNotEmpty) {
        int comp = subs.where((s) => s.completed).length;
        currentProgress = ((comp / subs.length) * 100).round();
      }
      return AppEvent(
        id: event.id,
        title: event.title,
        code: event.code,
        time: event.time,
        type: event.type,
        color: event.color,
        location: event.location,
        dueDate: event.dueDate,
        progress: currentProgress,
      );
    }).toList();
  }

  void _openDayDetails(DateTime date) {
    final key = _formatDateKey(date);
    final events = initialCalendarEvents[key] ?? [];
    final customForDay = _customEvents
        .where((e) => _formatDateKey(e.dueDate) == key)
        .toList();

    final allEventsForDay = [
      ...events,
      ...customForDay,
    ].where((e) => e.type != 'Lecture').toList();

    if (allEventsForDay.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) =>
            DayDetailsPopup(date: date, events: allEventsForDay),
      );
    }
  }

  void _openAddTask() {
    showDialog(
      context: context,
      builder: (context) => AddTaskPopup(
        onSave: (title, date, subtaskList) {
          final newEventId = DateTime.now().millisecondsSinceEpoch.toString();

          final newEvent = AppEvent(
            id: newEventId,
            title: title,
            code: "USER",
            time: "All Day",
            type: "TODO",
            color: nthuPurple,
            dueDate: date,
          );

          setState(() {
            _customEvents.add(newEvent);

            if (subtaskList.isNotEmpty) {
              _subtasksMap[newEventId] = subtaskList.asMap().entries.map((e) {
                return Subtask(id: "${newEventId}_${e.key}", text: e.value);
              }).toList();
            }

            final key = _formatDateKey(date);
            if (initialCalendarEvents[key] == null) {
              initialCalendarEvents[key] = [];
            }
            initialCalendarEvents[key]!.add(newEvent);
          });
        },
      ),
    );
  }

  void _openSubtaskManager(AppEvent event) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          final subs = _subtasksMap[event.id] ?? [];
          return SubtaskManagerPopup(
            event: event,
            subtasks: _subtasksMap[event.id] ?? [],
            onToggle: (subId) {
              setState(() {
                final sub = (_subtasksMap[event.id] ?? []).firstWhere(
                  (s) => s.id == subId,
                );
                sub.completed = !sub.completed;
              });
              setStateModal(() {});
            },
            onUpdate: () {
              setState(() {});
            },
            onAddSubtask: (newText) {
              setState(() {
                if (_subtasksMap[event.id] == null) {
                  _subtasksMap[event.id] = [];
                }

                _subtasksMap[event.id]!.add(
                  Subtask(
                    id: 'st-${DateTime.now().millisecondsSinceEpoch}',
                    text: newText,
                    completed: false,
                  ),
                );
              });
              setStateModal(() {});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents =
        _allUpcomingEvents
            .where(
              (e) => e.dueDate.isAfter(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            )
            .toList()
          ..sort((a, b) {
            bool aDone = _completedTaskIds.contains(a.id);
            bool bDone = _completedTaskIds.contains(b.id);
            if (aDone != bDone) return aDone ? 1 : -1;
            return a.dueDate.compareTo(b.dueDate);
          });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              
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
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showTutorial = true;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
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
                      _openDayDetails(date);
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

            // Floating Action Button (Fixed/Stationary to overlay viewport corner)
            Positioned(
              bottom: 32,
              right: 32,
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