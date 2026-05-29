import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';
import 'tutorial.dart';

// ----------------------------------------------------------------------
// UPCOMING TASKS WIDGET 
// ----------------------------------------------------------------------
class UpcomingTasksWidget extends StatefulWidget {
  final Function(AppEvent) onTaskTap;

  const UpcomingTasksWidget({
    Key? key,
    required this.onTaskTap, 
  }) : super(key: key);

  static final ValueNotifier<List<AppEvent>> tasksNotifier = ValueNotifier<List<AppEvent>>([]);

  static Color getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
      case 'midterm':
      case 'final':
        return const Color(0xFFFA3B4E); 
      case 'homework':
      case 'project':
        return const Color(0xFF02BCA4); 
      default:
        return const Color(0xFF752481); 
    }
  }

  @override
  State<UpcomingTasksWidget> createState() => _UpcomingTasksWidgetState();
}

class _UpcomingTasksWidgetState extends State<UpcomingTasksWidget> {
  List<AppEvent> _tasks = [];
  List<String> _completedTaskIds = [];
  bool _isLoading = true;
  
  final Set<String> _selectedFilters = {}; 
  String _selectedSort = 'DEADLINE'; 

  @override
  void initState() {
    super.initState();
    UpcomingTasksWidget.tasksNotifier.addListener(_onGlobalTasksChanged);
    _loadTasksFromJson();
  }

  @override
  void dispose() {
    UpcomingTasksWidget.tasksNotifier.removeListener(_onGlobalTasksChanged);
    super.dispose();
  }

  void _onGlobalTasksChanged() {
    if (mounted) {
      setState(() {
        _tasks = UpcomingTasksWidget.tasksNotifier.value;
      });
    }
  }

  int _getPriorityRank(String type) {
    switch (type.toLowerCase()) {
      case 'quiz':
      case 'midterm':
      case 'final':
        return 1;
      case 'homework':
      case 'project':
        return 2;
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

  Future<void> _loadTasksFromJson() async {
    if (UpcomingTasksWidget.tasksNotifier.value.isNotEmpty) {
      setState(() {
        _tasks = UpcomingTasksWidget.tasksNotifier.value;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final currentYear = DateTime.now().year;

    // MOVED ALL DUMMY DATA TO STRICTLY SPECIFIED JUNE DATES 
    List<AppEvent> initialTasks = [
      AppEvent(id: 'c1', title: 'OS Midterm Exam', code: 'CS3100', time: '14:00', type: 'midterm', color: UpcomingTasksWidget.getColorForType('midterm'), location: 'Room 101', progress: 0, dueDate: DateTime(currentYear, 6, 21)),
      AppEvent(id: 'c2', title: 'Algorithms Quiz 2', code: 'CS3200', time: '10:00', type: 'quiz', color: UpcomingTasksWidget.getColorForType('quiz'), location: 'Room 202', progress: 0, dueDate: DateTime(currentYear, 6, 24)),
      AppEvent(id: 'c3', title: 'Database Systems Final', code: 'CS3300', time: '09:00', type: 'final', color: UpcomingTasksWidget.getColorForType('final'), location: 'Room 303', progress: 0, dueDate: DateTime(currentYear, 6, 28)),
      AppEvent(id: 'c4', title: 'Comp Arch Pop Quiz', code: 'CS4100', time: '13:00', type: 'quiz', color: UpcomingTasksWidget.getColorForType('quiz'), location: 'Online', progress: 0, dueDate: DateTime(currentYear, 6, 21)),
      AppEvent(id: 'cw1', title: 'OS Memory Manager PA', code: 'CS3100', time: '23:59', type: 'project', color: UpcomingTasksWidget.getColorForType('project'), location: 'Online', progress: 30, dueDate: DateTime(currentYear, 6, 25)),
      AppEvent(id: 'cw2', title: 'Algo Dynamic Prog HW', code: 'CS3200', time: '23:59', type: 'homework', color: UpcomingTasksWidget.getColorForType('homework'), location: 'Online', progress: 80, dueDate: DateTime(currentYear, 6, 22)),
      AppEvent(id: 'cw3', title: 'Web Dev Frontend Phase', code: 'CS3400', time: '23:59', type: 'project', color: UpcomingTasksWidget.getColorForType('project'), location: 'Online', progress: 10, dueDate: DateTime(currentYear, 6, 27)),
      AppEvent(id: 'cw4', title: 'AI A* Search Assignment', code: 'CS4200', time: '23:59', type: 'homework', color: UpcomingTasksWidget.getColorForType('homework'), location: 'Online', progress: 0, dueDate: DateTime(currentYear, 6, 26)),
      AppEvent(id: 'cw5', title: 'ML Neural Nets Lab', code: 'CS4300', time: '23:59', type: 'homework', color: UpcomingTasksWidget.getColorForType('homework'), location: 'Online', progress: 50, dueDate: DateTime(currentYear, 6, 23)),
      AppEvent(id: 'cw6', title: 'DB Schema Design Proj', code: 'CS3300', time: '23:59', type: 'project', color: UpcomingTasksWidget.getColorForType('project'), location: 'Online', progress: 90, dueDate: DateTime(currentYear, 6, 24)),
      AppEvent(id: 'cw7', title: 'Networks Socket HW', code: 'CS4400', time: '23:59', type: 'homework', color: UpcomingTasksWidget.getColorForType('homework'), location: 'Online', progress: 0, dueDate: DateTime(currentYear, 6, 29)),
      AppEvent(id: 'cw8', title: 'Crypto RSA PA2', code: 'CS4500', time: '23:59', type: 'project', color: UpcomingTasksWidget.getColorForType('project'), location: 'Online', progress: 20, dueDate: DateTime(currentYear, 6, 21)),
    ];

    if (mounted) {
      UpcomingTasksWidget.tasksNotifier.value = initialTasks;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCountdown(DateTime dueDate) {
    final now = DateTime.now();
    final deadline = DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
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

  void _toggleComplete(String taskId) {
    setState(() {
      if (_completedTaskIds.contains(taskId)) {
        _completedTaskIds.remove(taskId);
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) _tasks[index].progress = 0;
      } else {
        _completedTaskIds.add(taskId);
        final index = _tasks.indexWhere((t) => t.id == taskId);
        if (index != -1) _tasks[index].progress = 100;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = _tasks.where((t) => !_completedTaskIds.contains(t.id)).toList();
    final completedTasks = _tasks.where((t) => _completedTaskIds.contains(t.id)).toList();

    _sortTasks(activeTasks);
    _sortTasks(completedTasks);

    final displayTasks = [...activeTasks, ...completedTasks];

    final filteredDisplayTasks = displayTasks.where((task) {
      if (_selectedFilters.isEmpty) return true; 
      
      final type = task.type.toLowerCase();
      bool matchesCritical = ['quiz', 'midterm', 'final'].contains(type);
      bool matchesCoursework = ['homework', 'project'].contains(type);
      bool matchesTodo = !matchesCritical && !matchesCoursework;

      if (_selectedFilters.contains('CRITICAL') && matchesCritical) return true;
      if (_selectedFilters.contains('COURSEWORK') && matchesCoursework) return true;
      if (_selectedFilters.contains('TODO') && matchesTodo) return true;

      return false;
    }).toList();

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
          )
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
                child: Icon(Icons.rocket_launch_rounded, color: Colors.orange.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Upcoming",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
              ),
              const Spacer(),
              
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: "", 
                  icon: const Icon(Icons.swap_vert_rounded, size: 18, color: Colors.grey),
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
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'PRIORITY',
                      padding: EdgeInsets.zero,
                      child: _HoverMenuItem(
                        text: "PRIORITY", 
                        isSelected: _selectedSort == 'PRIORITY'
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'DEADLINE',
                      padding: EdgeInsets.zero,
                      child: _HoverMenuItem(
                        text: "DEADLINE", 
                        isSelected: _selectedSort == 'DEADLINE'
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InteractiveFilterTag(
                label: 'CRITICAL', 
                baseColor: const Color(0xFFFA3B4E), 
                isActive: _selectedFilters.contains('CRITICAL'),
                onTap: () => setState(() => _selectedFilters.contains('CRITICAL') ? _selectedFilters.remove('CRITICAL') : _selectedFilters.add('CRITICAL')),
              ),
              _InteractiveFilterTag(
                label: 'COURSEWORK', 
                baseColor: const Color(0xFF02BCA4), 
                isActive: _selectedFilters.contains('COURSEWORK'),
                onTap: () => setState(() => _selectedFilters.contains('COURSEWORK') ? _selectedFilters.remove('COURSEWORK') : _selectedFilters.add('COURSEWORK')),
              ),
              _InteractiveFilterTag(
                label: 'TODO', 
                baseColor: const Color(0xFF752481), 
                isActive: _selectedFilters.contains('TODO'),
                onTap: () => setState(() => _selectedFilters.contains('TODO') ? _selectedFilters.remove('TODO') : _selectedFilters.add('TODO')),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Colors.orange),
              )
            )
          else if (filteredDisplayTasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: Colors.grey.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey.shade100, style: BorderStyle.solid), 
              ),
              child: const Text(
                "NO MATCHING EVENTS",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
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

                return _UpcomingTaskItem(
                  key: index == 0 ? TutorialTargetRegistry.get('upcoming-item-0') : null,
                  task: task,
                  isCompleted: isCompleted,
                  countdownStr: _formatCountdown(task.dueDate),
                  onToggleComplete: _toggleComplete,
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
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isActive ? widget.baseColor : widget.baseColor.withOpacity(_isHovered ? 0.15 : 0.06), 
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHovered && widget.isActive 
                ? [BoxShadow(color: widget.baseColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
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
  bool _isPressed = false;

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
        color: widget.isCompleted ? Colors.grey.shade300 : Colors.green,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: widget.isCompleted ? const SizedBox.shrink() : _buildCelebrationWidget(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: widget.isCompleted ? const SizedBox.shrink() : _buildCelebrationWidget(),
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
            onTapDown: (_) { if (!widget.isCompleted) setState(() => _isPressed = true); },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              if (!widget.isCompleted) widget.onTaskTap(widget.task);
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : (_isHovered && !widget.isCompleted ? 1.02 : 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isHovered && !widget.isCompleted ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _isHovered && !widget.isCompleted ? Colors.grey.shade200 : Colors.transparent),
                  boxShadow: _isHovered && !widget.isCompleted
                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
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
                                  color: widget.isCompleted ? Colors.grey : const Color(0xFF752481).withOpacity(0.6),
                                ),
                              ),
                              if (!widget.isCompleted)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isHovered ? Colors.orange.shade100 : Colors.orange.shade50,
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
                                )
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
                              color: widget.isCompleted ? Colors.grey : Colors.black87,
                              decoration: widget.isCompleted ? TextDecoration.lineThrough : null,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(widget.task.color),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${widget.task.progress}%",
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey),
                                )
                              ],
                            )
                          ]
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
      Colors.white, Colors.yellowAccent, Colors.pink.shade200, 
      Colors.cyanAccent, Colors.orangeAccent, Colors.white
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
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 6), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}