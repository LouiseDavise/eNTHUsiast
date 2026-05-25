import 'dart:ui';
import 'package:flutter/material.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';
import 'tutorial.dart';

class SubtaskManagerPopup extends StatefulWidget {
  final AppEvent event;
  final List<Subtask> subtasks;
  final Function(String) onToggle;
  final VoidCallback onUpdate;
  final Function(String) onAddSubtask; 

  const SubtaskManagerPopup({
    Key? key, 
    required this.event, 
    required this.subtasks, 
    required this.onToggle, 
    required this.onUpdate,
    required this.onAddSubtask,
  }) : super(key: key);

  @override
  State<SubtaskManagerPopup> createState() => _SubtaskManagerPopupState();
}

class _SubtaskManagerPopupState extends State<SubtaskManagerPopup> {
  final TextEditingController _subtaskCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    int completed = widget.subtasks.where((s) => s.completed).length;
    int total = widget.subtasks.length;
    int progress = total > 0 ? ((completed / total) * 100).round() : widget.event.progress;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), 
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          key: TutorialTargetRegistry.get('subtask-modal-content'),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.event.title, maxLines: 2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.black, height: 1.1)),
                        const SizedBox(height: 6),
                        Text("CHECKLIST & PROGRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context), 
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 20),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("TOTAL PROGRESS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                  Text("$progress%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress / 100, 
                  backgroundColor: Colors.grey.shade100, 
                  valueColor: AlwaysStoppedAnimation<Color>(widget.event.color), 
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                key: TutorialTargetRegistry.get('subtask-add-row'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _subtaskCtrl,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: "Add a subtask...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) {
                          if (_subtaskCtrl.text.trim().isNotEmpty) {
                            widget.onAddSubtask(_subtaskCtrl.text.trim());
                            _subtaskCtrl.clear();
                            setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    width: 64,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_subtaskCtrl.text.trim().isNotEmpty) {
                          widget.onAddSubtask(_subtaskCtrl.text.trim());
                          _subtaskCtrl.clear();
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nthuPurple, 
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    ),
                  )
                ],
              ),
              
              if (widget.subtasks.isNotEmpty) ...[
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.subtasks.length,
                    itemBuilder: (context, index) {
                      final st = widget.subtasks[index];
                      return GestureDetector(
                        onTap: () {
                          widget.onToggle(st.id);
                          TutorialTargetRegistry.fireAction(); 
                        },
                        child: Container(
                          key: index == widget.subtasks.length - 1 
                              ? TutorialTargetRegistry.get('subtask-new-item') 
                              : null,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: st.completed ? Colors.green : Colors.white, 
                                  border: Border.all(color: st.completed ? Colors.green : Colors.grey.shade300, width: 2), 
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: st.completed ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  st.text, 
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: st.completed ? Colors.grey : Colors.black87, 
                                    decoration: st.completed ? TextDecoration.lineThrough : null
                                  )
                                )
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  key: TutorialTargetRegistry.get('subtask-update-btn'),
                  onPressed: () {
                    widget.event.progress = progress; 
                    widget.onUpdate(); 
                    
                    // ✅ YOUR GENIUS FIX! Safely triggers Tip 10 instantly.
                    TutorialTargetRegistry.fireAction();
                    
                    Navigator.pop(context); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nthuPurple, 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Text("UPDATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}