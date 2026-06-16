import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../utilities/models.dart';
import 'tutorial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/event_prioritization_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpcomingTasksWidget extends StatefulWidget {
  final Function(AppEvent) onTaskTap;

  const UpcomingTasksWidget({Key? key, required this.onTaskTap})
    : super(key: key);

  static final ValueNotifier<List<AppEvent>> tasksNotifier =
      ValueNotifier<List<AppEvent>>([]);

  static Color getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFA3B4E);
      case 'coursework':
        return const Color(0xFF02BCA4);
      case 'todo':
      default:
        return const Color(0xFF752481);
    }
  }

  @override
  State<UpcomingTasksWidget> createState() => _UpcomingTasksWidgetState();
}

class _UpcomingTasksWidgetState extends State<UpcomingTasksWidget>
    with SingleTickerProviderStateMixin {
  List<AppEvent> _tasks = [];
  Set<String> _completedTaskIds = {};
  bool _isLoading = true;
  bool _isAgentMode = true;
  bool _isSyncing = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSubscription;

  final Set<String> _selectedFilters = {};
  String _selectedSort = 'DEADLINE';
  bool _isSortHovered = false;

  // Spin animation for the sync button
  late final AnimationController _syncSpinCtrl;

  // Auto-sync every 10 seconds; only fires if no sync is already running
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();

    // Continuous rotation — we start/stop it based on _isSyncing
    _syncSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    UpcomingTasksWidget.tasksNotifier.addListener(_onGlobalTasksChanged);
    _fetchTasksFromFirestore();
    _triggerAgentSync(); // initial sync on load

    // Auto-sync every 10 s; _triggerAgentSync() is a no-op while already syncing
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 100000), (_) {
      _triggerAgentSync();
    });
  }

  @override
  void dispose() {
    _syncSpinCtrl.dispose();
    _autoSyncTimer?.cancel();
    UpcomingTasksWidget.tasksNotifier.removeListener(_onGlobalTasksChanged);
    _tasksSubscription?.cancel();
    super.dispose();
  }

  void _onGlobalTasksChanged() {
    if (mounted) {
      setState(() {
        _tasks = UpcomingTasksWidget.tasksNotifier.value;
      });
    }
  }

  void _triggerAgentSync() async {
    // Guard set SYNCHRONOUSLY before any await — this is the real mutex.
    // _isSyncing inside setState() is only for UI rebuilds; it cannot block
    // a second timer-fired call that arrives before the first setState flushes.
    if (_isSyncing) {
      print("⏳ Sync already in progress. Ignoring.");
      return;
    }
    _isSyncing = true; // lock immediately, synchronously, before any await

    _syncSpinCtrl.repeat();
    if (mounted) setState(() {}); // trigger UI rebuild to show spinner
    print("🔄 Sync Triggered! Waking up Agent...");

    try {
      final agentService = EventPrioritizationService();
      await agentService.connectAndAnalyze();
    } finally {
      // Always unlock — even if connectAndAnalyze() throws
      _isSyncing = false;
      if (mounted) {
        _syncSpinCtrl.stop();
        _syncSpinCtrl.reset();
        setState(() {});
      }
    }
  }

  int _getPriorityRank(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return 1;
      case 'coursework':
        return 2;
      case 'todo':
      default:
        return 3;
    }
  }

  void _sortTasks(List<AppEvent> tasks) {
    if (_selectedSort == 'DEADLINE') {
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } else {
      tasks.sort((a, b) {
        int rankA = _getPriorityRank(a.type);
        int rankB = _getPriorityRank(b.type);
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        return a.dueDate.compareTo(b.dueDate);
      });
    }
  }

  Future<void> _fetchTasksFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("错误：用户未登录 Firebase，无法加载任务。");
      setState(() => _isLoading = false);
      return;
    }

    _tasksSubscription = FirebaseFirestore.instance
        .collection('ccxpUsers')
        .doc(uid)
        .collection('upcoming')
        .snapshots()
        .listen((snapshot) {
          List<AppEvent> fetchedTasks = snapshot.docs.map((doc) {
            try {
              final data = doc.data();
              List<Subtask> parsedSubtasks = [];
              if (data['subtasks'] != null) {
                parsedSubtasks = (data['subtasks'] as List<dynamic>).map((st) {
                  if (st is Map<String, dynamic>) {
                    return Subtask(
                      id: st['id']?.toString() ?? UniqueKey().toString(),
                      text: st['text']?.toString() ?? '',
                      completed: st['completed'] ?? false,
                    );
                  } else if (st is String) {
                    return Subtask(
                      id: UniqueKey().toString(),
                      text: st,
                      completed: false,
                    );
                  }
                  return Subtask(
                    id: UniqueKey().toString(),
                    text: 'Unknown task',
                    completed: false,
                  );
                }).toList();
              }
              DateTime parsedDate = DateTime.now();
              if (data['dueDate'] is Timestamp) {
                parsedDate = (data['dueDate'] as Timestamp).toDate();
              } else if (data['dueDate'] != null) {
                parsedDate = DateTime.parse(data['dueDate'].toString());
              }

              return AppEvent(
                id: doc.id,
                title: data['title'] ?? 'Untitled Task',
                code: data['code'] ?? 'N/A',
                time: data['time'] ?? '23:59',
                type: data['type'] ?? 'todo',
                color: UpcomingTasksWidget.getColorForType(
                  data['type'] ?? 'todo',
                ),
                priorityScore: (data['priorityScore'] as num?)?.toInt() ?? 0,
                location: data['location'] ?? 'Online',
                progress: data['progress'] ?? 0,
                dueDate: parsedDate,
                subtasks: parsedSubtasks,
                summary: data['summary']?.toString(),   // ← fixed cast
              );
            } catch (e) {
              return null;                               // ← skip bad doc
            }
          }).whereType<AppEvent>().toList();        

          if (mounted) {
            // 从 Firebase 恢复已持久化的完成状态。
            // Pulihkan status selesai yang sudah tersimpan dari Firebase.
            final restoredCompleted = <String>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data['markCompleted'] == true) {
                restoredCompleted.add(doc.id);
              }
            }
            _purgeOverdueTasks(fetchedTasks);
            UpcomingTasksWidget.tasksNotifier.value = fetchedTasks;
            setState(() {
              _tasks = fetchedTasks;
              _completedTaskIds = restoredCompleted;
              _isLoading = false;
            });
          }
        });
  }

  String _formatCountdown(AppEvent task) {
    final now = DateTime.now();

    final timeParts = task.time.split(':');
    final int hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 23 : 23;
    final int minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 59 : 59;
    final deadline = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      hour,
      minute,
      59,
    );
    final diff = deadline.difference(now);

    if (diff.isNegative) return "Overdue";

    final weeks = diff.inDays ~/ 7;
    final days = diff.inDays % 7;
    final hours = diff.inHours % 24;

    List<String> parts = [];
    if (weeks > 0) parts.add("${weeks}W");
    if (days > 0) parts.add("${days}D");
    if (hours > 0 || parts.isEmpty) parts.add("${hours}H");

    return parts.join(" ");
  }

  void _toggleTaskCompletion(String taskId) async {
    final task = _tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('not found'),
    );
    final bool nowCompleting = !_completedTaskIds.contains(taskId);
    final timeParts = task.time.split(':');
    final int hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 23 : 23;
    final int minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 59 : 59;

    final bool isOverdue = DateTime.now().isAfter(
      DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
        hour,
        minute,
        59,
      ),
    );

    // 仅在任务已过期且被标记为完成时，才从 Firebase 中永久删除。
    // Hanya hapus permanen jika tugas sudah overdue DAN sedang ditandai selesai.
    if (nowCompleting && isOverdue) {
      await _deleteTaskFromFirebase(taskId);
      UpcomingTasksWidget.tasksNotifier.value = UpcomingTasksWidget
          .tasksNotifier
          .value
          .where((task) => task.id != taskId)
          .toList();
      setState(() {
        _tasks.removeWhere((t) => t.id == taskId);
        _completedTaskIds.remove(taskId);
      });
      return;
    }

    setState(() {
      if (nowCompleting) {
        _completedTaskIds.add(taskId);
      } else {
        _completedTaskIds.remove(taskId);
      }
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(uid)
          .collection('upcoming')
          .doc(taskId)
          .update({
            'markCompleted': nowCompleting,
            if (nowCompleting) 'completedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("错误：更新任务完成标记失败 → $e");
    }
  }

  Future<void> _deleteTaskFromFirebase(String taskId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(uid)
          .collection('upcoming')
          .doc(taskId)
          .delete();
    } catch (e) {
      print("Failed to delete overdue task: $e");
    }
  }

  /// After fetching, remove any overdue tasks from Firebase automatically.
  void _purgeOverdueTasks(List<AppEvent> tasks) async {
    final now = DateTime.now();
    for (final task in tasks) {
      final timeParts = task.time.split(':');
      final int hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 23 : 23;
      final int minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 59 : 59;

      final deadline = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
        hour,
        minute,
        59,
      );
      if (now.isAfter(deadline)) {
        await _deleteTaskFromFirebase(task.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Grab all active uncompleted tasks as you originally do
    final activeTasks = _tasks
        .where((t) => !_completedTaskIds.contains(t.id))
        .toList();

    // 2. This list will hold whichever tasks survive the current mode's rules
    List<AppEvent> filteredActiveTasks;

    if (_isAgentMode) {
      // ---- MODE A: AI AUTOPILOT ----
      // For now, we temporarily sort by task progress as a fallback placeholder.
      // We also bypass the tags entirely so everything shows up sorted by the AI.
      activeTasks.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      filteredActiveTasks = activeTasks;
    } else {
      // ---- MODE B: USER CUSTOM SORT & FILTER (Your Original Logic) ----
      _sortTasks(activeTasks);

      bool _matchesFilter(AppEvent task) {
        if (_selectedFilters.isEmpty) return true;
        final type = task.type.toLowerCase();
        bool matchesCritical = ['critical'].contains(type);
        bool matchesCoursework = ['coursework'].contains(type);
        bool matchesTodo = !matchesCritical && !matchesCoursework;
        if (_selectedFilters.contains('CRITICAL') && matchesCritical) return true;
        if (_selectedFilters.contains('COURSEWORK') && matchesCoursework) return true;
        if (_selectedFilters.contains('TODO') && matchesTodo) return true;
        return false;
      }

      filteredActiveTasks = activeTasks.where(_matchesFilter).toList();
    }

    // 3. Keep completed tasks stacked gracefully at the bottom
    final completedTasks = _tasks
        .where((t) => _completedTaskIds.contains(t.id))
        .toList();

    // 4. Combine them to generate the final array for the ListView renderer
    final filteredDisplayTasks = [...filteredActiveTasks, ...completedTasks];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Upcoming",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              
              // Spacer pushes the button to the far right
              const Spacer(),

              // Animated sync button — spins while any sync is in progress
              Tooltip(
                message: "",
                child: GestureDetector(
                  onTap: _isSyncing ? null : _triggerAgentSync,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isSyncing
                          ? Colors.orange.shade50
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RotationTransition(
                      turns: _syncSpinCtrl,
                      child: Icon(
                        Icons.sync_rounded,
                        size: 20,
                        color: _isSyncing
                            ? Colors.orange.shade400
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),

              // ---- THE DUAL MODE TOGGLE BUTTON (ICON ONLY, TOP RIGHT) ----
              GestureDetector(
                onTap: () => setState(() => _isAgentMode = !_isAgentMode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8), // Uniform padding for a square/circle button
                  decoration: BoxDecoration(
                    color: _isAgentMode ? Colors.purple.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAgentMode ? Colors.purple.shade200 : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    _isAgentMode ? Icons.auto_awesome_rounded : Icons.tune_rounded,
                    size: 20,
                    color: _isAgentMode ? Colors.purple : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Show tag configuration selectors AND sort dropdown only in manual sort mode
          if (!_isAgentMode) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center, // Vertically aligns the dropdown with the tags
              children: [
                // ---- MANUAL SORT BUTTON (MOVED HERE, LEFT-MOST) ----
                MouseRegion(
                  onEnter: (_) => setState(() => _isSortHovered = true),
                  onExit: (_) => setState(() => _isSortHovered = false),
                  child: AnimatedScale(
                    scale: _isSortHovered ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: Container(
                      height: 34,
                      width: 34, // Matches the height of your tags roughly
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isSortHovered
                              ? Colors.grey.shade300
                              : Colors.grey.shade100,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        tooltip: "",
                        icon: Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: _isSortHovered ? Colors.black87 : Colors.grey,
                        ),
                        onSelected: (String value) {
                          setState(() {
                            _selectedSort = value;
                          });
                        },
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        offset: const Offset(0, 42),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'PRIORITY',
                                padding: EdgeInsets.zero,
                                child: _HoverMenuItem(
                                  text: "PRIORITY",
                                  isSelected: _selectedSort == 'PRIORITY',
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'DEADLINE',
                                padding: EdgeInsets.zero,
                                child: _HoverMenuItem(
                                  text: "DEADLINE",
                                  isSelected: _selectedSort == 'DEADLINE',
                                ),
                              ),
                            ],
                      ),
                    ),
                  ),
                ),

                // ---- FILTER TAGS ----
                _InteractiveFilterTag(
                  label: 'CRITICAL',
                  baseColor: const Color(0xFFFA3B4E),
                  isActive: _selectedFilters.contains('CRITICAL'),
                  onTap: () => setState(
                    () => _selectedFilters.contains('CRITICAL')
                        ? _selectedFilters.remove('CRITICAL')
                        : _selectedFilters.add('CRITICAL'),
                  ),
                ),
                _InteractiveFilterTag(
                  label: 'COURSEWORK',
                  baseColor: const Color(0xFF02BCA4),
                  isActive: _selectedFilters.contains('COURSEWORK'),
                  onTap: () => setState(
                    () => _selectedFilters.contains('COURSEWORK')
                        ? _selectedFilters.remove('COURSEWORK')
                        : _selectedFilters.add('COURSEWORK'),
                  ),
                ),
                _InteractiveFilterTag(
                  label: 'TODO',
                  baseColor: const Color(0xFF752481),
                  isActive: _selectedFilters.contains('TODO'),
                  onTap: () => setState(
                    () => _selectedFilters.contains('TODO')
                        ? _selectedFilters.remove('TODO')
                        : _selectedFilters.add('TODO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          else if (filteredDisplayTasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: Colors.grey.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.grey.shade100,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Text(
                "NO MATCHING EVENTS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDisplayTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = filteredDisplayTasks[index];
                final isCompleted = _completedTaskIds.contains(task.id);
                final isFirstAvailableTask =
                    !isCompleted &&
                    filteredActiveTasks.isNotEmpty &&
                    filteredActiveTasks.first.id == task.id;

                return _UpcomingTaskItem(
                  key: isFirstAvailableTask
                      ? TutorialTargetRegistry.get('upcoming-item-0')
                      : null,
                  task: task,
                  isCompleted: isCompleted,
                  countdownStr: _formatCountdown(task),
                  onToggleComplete: _toggleTaskCompletion,
                  onTaskTap: widget.onTaskTap,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InteractiveFilterTag extends StatefulWidget {
  final String label;
  final Color baseColor;
  final bool isActive;
  final VoidCallback onTap;

  const _InteractiveFilterTag({
    required this.label,
    required this.baseColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_InteractiveFilterTag> createState() => _InteractiveFilterTagState();
}

class _InteractiveFilterTagState extends State<_InteractiveFilterTag> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? widget.baseColor
                  : widget.baseColor.withOpacity(_isHovered ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? widget.baseColor.withOpacity(0.55)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: _isHovered && widget.isActive
                  ? [
                      BoxShadow(
                        color: widget.baseColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: widget.isActive ? Colors.white : widget.baseColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverMenuItem extends StatefulWidget {
  final String text;
  final bool isSelected;

  const _HoverMenuItem({required this.text, required this.isSelected});

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFF752481)
              : (_isHovered ? Colors.grey.shade100 : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: widget.isSelected ? Colors.white : Colors.grey.shade600,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _UpcomingTaskItem extends StatefulWidget {
  final AppEvent task;
  final bool isCompleted;
  final String countdownStr;
  final Function(String) onToggleComplete;
  final Function(AppEvent) onTaskTap;

  const _UpcomingTaskItem({
    Key? key,
    required this.task,
    required this.isCompleted,
    required this.countdownStr,
    required this.onToggleComplete,
    required this.onTaskTap,
  }) : super(key: key);

  @override
  State<_UpcomingTaskItem> createState() => _UpcomingTaskItemState();
}

class _UpcomingTaskItemState extends State<_UpcomingTaskItem> {
  double _swipeProgress = 0.0;
  bool _isHovered = false;

  Widget _buildCelebrationWidget() {
    double burstProgress = ((_swipeProgress - 0.15) / 0.4).clamp(0.0, 1.0);
    double opacity = 1.0 - ((_swipeProgress - 0.7) / 0.3).clamp(0.0, 1.0);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_swipeProgress > 0.15)
            Opacity(
              opacity: opacity,
              child: CustomPaint(
                size: const Size(56, 56),
                painter: _ParticlePainter(progress: burstProgress),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget swipeBackground = Container(
      decoration: BoxDecoration(
        // 完成 → 绿色；撤销 → 橙色（带纸屑动画）
        // Selesai → hijau; undo → oranye (dengan animasi confetti)
        color: widget.isCompleted ? Colors.orange.shade400 : Colors.green,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: _buildCelebrationWidget(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _buildCelebrationWidget(),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Dismissible(
        key: Key('${widget.task.id}_${widget.isCompleted}'),
        direction: DismissDirection.horizontal,
        onUpdate: (details) {
          setState(() {
            _swipeProgress = details.progress;
          });
        },
        onDismissed: (_) {
          widget.onToggleComplete(widget.task.id);
          TutorialTargetRegistry.fireAction();
        },
        background: swipeBackground,
        secondaryBackground: swipeBackground,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.isCompleted
                ? null
                : () => widget.onTaskTap(widget.task),
            child: AnimatedScale(
              scale: _isHovered && !widget.isCompleted ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isHovered && !widget.isCompleted
                      ? Colors.white
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isHovered && !widget.isCompleted
                        ? Colors.grey.shade200
                        : Colors.transparent,
                  ),
                  boxShadow: _isHovered && !widget.isCompleted
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                foregroundDecoration: widget.isCompleted
                    ? BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        backgroundBlendMode: BlendMode.saturation,
                        borderRadius: BorderRadius.circular(24),
                      )
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.task.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.task.code.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: widget.isCompleted
                                      ? Colors.grey
                                      : const Color(
                                          0xFF752481,
                                        ).withOpacity(0.6),
                                ),
                              ),
                              if (!widget.isCompleted)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isHovered
                                        ? Colors.orange.shade100
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.countdownStr,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: Colors.orange.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.isCompleted
                                  ? Colors.black54
                                  : Colors.black87,
                              decoration: widget.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: widget.isCompleted
                                  ? Colors.black87
                                  : null,
                              decorationThickness: widget.isCompleted
                                  ? 2.5
                                  : null,
                            ),
                          ),
                          if (!widget.isCompleted) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: widget.task.progress / 100,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        widget.task.color,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${widget.task.progress}%",
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [
      Colors.white,
      Colors.yellowAccent,
      Colors.pink.shade200,
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.white,
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final distance = 14.0 + (progress * 28.0);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      paint.color = colors[i % colors.length];

      if (i % 2 == 0) {
        canvas.drawCircle(Offset(x, y), 3.0 + (1 - progress) * 2, paint);
      } else {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * math.pi * 2);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 6, height: 6),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}