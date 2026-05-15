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
    // Replicating TSX logic to set time to end of day for due date
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
              // (Sort & Filter menus would go here - handled in Main Screen state usually, 
              // but for brevity we'll leave placeholder buttons)
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
                border: Border.all(color: Colors.grey.shade100, style: BorderStyle.solid), // Changed from dashed since flutter doesn't natively support dashed borders without custom painters
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

                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) {
                    onToggleComplete(task.id);
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (!isCompleted) onTaskTap(task);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      foregroundDecoration: isCompleted
                          ? BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              backgroundBlendMode: BlendMode.saturation,
                            )
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 60,
                            decoration: BoxDecoration(
                              color: task.color,
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
                                      task.code.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        color: isCompleted ? Colors.grey : nthuPurple.withOpacity(0.6),
                                      ),
                                    ),
                                    if (!isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _formatCountdown(task.dueDate),
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
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? Colors.grey : Colors.black87,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (!isCompleted) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: task.progress / 100,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(task.color),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${task.progress}%",
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
                );
              },
            ),
        ],
      ),
    );
  }
}