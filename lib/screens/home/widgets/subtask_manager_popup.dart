import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';

class SubtaskManagerPopup extends StatelessWidget {
  final AppEvent event;
  final List<Subtask> subtasks;
  final Function(String) onToggle;
  final VoidCallback onUpdate;

  const SubtaskManagerPopup({Key? key, required this.event, required this.subtasks, required this.onToggle, required this.onUpdate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int completed = subtasks.where((s) => s.completed).length;
    int total = subtasks.length;
    int progress = total > 0 ? ((completed / total) * 100).round() : event.progress;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.black)),
                      const Text("CHECKLIST & PROGRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
                    ],
                  ),
                ),
                IconButton(onPressed: onUpdate, icon: const Icon(Icons.close_rounded), style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50))
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL PROGRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
                Text("$progress%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: progress == 100 ? Colors.green : Colors.black)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(event.color), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 24),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: subtasks.length,
                itemBuilder: (context, index) {
                  final st = subtasks[index];
                  return GestureDetector(
                    onTap: () => onToggle(st.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: st.completed ? Colors.green : Colors.white, border: Border.all(color: st.completed ? Colors.green : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(8)),
                            child: st.completed ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Text(st.text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: st.completed ? Colors.grey : Colors.black87, decoration: st.completed ? TextDecoration.lineThrough : null))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(backgroundColor: nthuPurple, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: const Text("UPDATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            )
          ],
        ),
      ),
    );
  }
}