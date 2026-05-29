import 'dart:ui';
import 'package:flutter/material.dart';
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
  bool _isAddHovered = false;
  bool _isUpdateHovered = false;
  bool _isCloseHovered = false;

  @override
  Widget build(BuildContext context) {
    const nthuPurple = Color(0xFF7E22CE);
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
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20))],
          ),
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
                  MouseRegion(
                    onEnter: (_) => setState(() => _isCloseHovered = true),
                    onExit: (_) => setState(() => _isCloseHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _isCloseHovered ? Colors.grey.shade200 : Colors.grey.shade50, 
                        shape: BoxShape.circle
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context), 
                        icon: Icon(Icons.close_rounded, color: _isCloseHovered ? Colors.black : Colors.grey.shade600, size: 20),
                      ),
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
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: progress / 100),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value, 
                    backgroundColor: Colors.grey.shade100, 
                    valueColor: AlwaysStoppedAnimation<Color>(widget.event.color), 
                    minHeight: 10,
                  ),
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
                  MouseRegion(
                    onEnter: (_) => setState(() => _isAddHovered = true),
                    onExit: (_) => setState(() => _isAddHovered = false),
                    child: AnimatedScale(
                      scale: _isAddHovered ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutBack,
                      child: SizedBox(
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
                            elevation: _isAddHovered ? 8 : 0,
                            shadowColor: nthuPurple.withOpacity(0.4),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                        ),
                      ),
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
                      return _InteractiveSubtaskRow(
                        key: index == widget.subtasks.length - 1 ? TutorialTargetRegistry.get('subtask-new-item') : null,
                        subtask: st,
                        onToggle: () {
                          widget.onToggle(st.id);
                          TutorialTargetRegistry.fireAction(); 
                        },
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              MouseRegion(
                onEnter: (_) => setState(() => _isUpdateHovered = true),
                onExit: (_) => setState(() => _isUpdateHovered = false),
                child: AnimatedScale(
                  scale: _isUpdateHovered ? 1.02 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      key: TutorialTargetRegistry.get('subtask-update-btn'),
                      onPressed: () {
                        widget.event.progress = progress; 
                        widget.onUpdate(); 
                        TutorialTargetRegistry.fireAction();
                        Navigator.pop(context); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nthuPurple, 
                        elevation: _isUpdateHovered ? 10 : 0,
                        shadowColor: nthuPurple.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      child: const Text("UPDATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// INTERACTIVE SUBTASK ROW (NEW)
// ----------------------------------------------------------------------
class _InteractiveSubtaskRow extends StatefulWidget {
  final Subtask subtask;
  final VoidCallback onToggle;

  const _InteractiveSubtaskRow({Key? key, required this.subtask, required this.onToggle}) : super(key: key);

  @override
  State<_InteractiveSubtaskRow> createState() => _InteractiveSubtaskRowState();
}

class _InteractiveSubtaskRowState extends State<_InteractiveSubtaskRow> {
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
          widget.onToggle();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isHovered ? Colors.white : Colors.grey.shade50, 
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isHovered ? Colors.grey.shade200 : Colors.transparent),
              boxShadow: _isHovered ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))] : [],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: widget.subtask.completed ? Colors.green : Colors.white, 
                    border: Border.all(color: widget.subtask.completed ? Colors.green : Colors.grey.shade300, width: 2), 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: widget.subtask.completed ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: widget.subtask.completed ? Colors.grey : Colors.black87, 
                      decoration: widget.subtask.completed ? TextDecoration.lineThrough : TextDecoration.none
                    ),
                    child: Text(widget.subtask.text),
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}