import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';

class UpcomingTasksWidget extends StatelessWidget {
  final List<AppEvent> filteredEvents;
  final List<String> completedTaskIds;
  final Function(String) onToggleComplete;
  final Function(AppEvent) onTaskTap;

  const UpcomingTasksWidget({
    Key? key,
    required this.filteredEvents,
    required this.completedTaskIds,
    required this.onToggleComplete,
    required this.onTaskTap,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
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
          // Header
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
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900,
                  color: Colors.black),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded, color: nthuPurple),
                onPressed: () {},
                style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List of Tasks
          if (filteredEvents.isEmpty)
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
              itemCount: filteredEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = filteredEvents[index];
                final isCompleted = completedTaskIds.contains(task.id);

                return _UpcomingTaskItem(
                  task: task,
                  isCompleted: isCompleted,
                  countdownStr: _formatCountdown(task.dueDate),
                  onToggleComplete: onToggleComplete,
                  onTaskTap: onTaskTap,
                );
              },
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// NEW: Stateful Widget to track Drag Progress for the Confetti Animation
// ----------------------------------------------------------------------
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

  // Builds the dynamic confetti WITHOUT the tick symbol
  Widget _buildCelebrationWidget() {
    double burstProgress = ((_swipeProgress - 0.15) / 0.4).clamp(0.0, 1.0);
    double opacity = 1.0 - ((_swipeProgress - 0.7) / 0.3).clamp(0.0, 1.0);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti particle painter
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
    // The native background that sits behind the card
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
            child: widget.isCompleted
                ? const SizedBox.shrink()
                : _buildCelebrationWidget(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: widget.isCompleted
                ? const SizedBox.shrink()
                : _buildCelebrationWidget(),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Dismissible(
        // THE MAGIC FIX: By changing the key based on completion status, 
        // Flutter lets the card slide completely off the screen without crashing!
        key: Key('${widget.task.id}_${widget.isCompleted}'),
        direction: DismissDirection.horizontal,
        onUpdate: (details) {
          setState(() {
            _swipeProgress = details.progress;
          });
        },
        onDismissed: (_) {
          widget.onToggleComplete(widget.task.id);
        },
        background: swipeBackground,
        secondaryBackground: swipeBackground,
        child: GestureDetector(
          onTap: () {
            if (!widget.isCompleted) widget.onTaskTap(widget.task);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24), // Keeps the white card rounded
            ),
            foregroundDecoration: widget.isCompleted
                ? BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    backgroundBlendMode: BlendMode.saturation,
                    borderRadius: BorderRadius.circular(24), // Prevents sharp overlay corners
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
                              color: widget.isCompleted ? Colors.grey : nthuPurple.withOpacity(0.6),
                            ),
                          ),
                          if (!widget.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
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
    );
  }
}

// ----------------------------------------------------------------------
// NEW: Custom Painter for the Confetti Particles
// ----------------------------------------------------------------------
class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Vibrant colors that pop against the green background
    final colors = [
      Colors.white, 
      Colors.yellowAccent, 
      Colors.pink.shade200, 
      Colors.cyanAccent, 
      Colors.orangeAccent, 
      Colors.white
    ];
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw 6 particles spreading out in a circle
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      // Distance pushes outward as swipe progress increases
      final distance = 14.0 + (progress * 28.0);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      paint.color = colors[i % colors.length];

      if (i % 2 == 0) {
        // Draw shrinking circles
        canvas.drawCircle(Offset(x, y), 3.0 + (1 - progress) * 2, paint);
      } else {
        // Draw spinning squares
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * math.pi * 2); // Spin effect
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 6, height: 6), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}