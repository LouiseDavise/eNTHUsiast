import 'dart:ui';
import 'package:flutter/material.dart';
import '../utilities/models.dart';
import 'tutorial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'priority_detail.dart';
import 'package:intl/intl.dart';

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
  bool _isUpdating = false;

  Future<void> _saveToFirestore(int currentProgress) async {
    setState(() => _isUpdating = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception("Not logged in to Firebase. Please log in again.");
      }

      final List<Map<String, dynamic>> subtasksMap = widget.subtasks
          .map(
            (st) => {'id': st.id, 'text': st.text, 'completed': st.completed},
          )
          .toList();

      await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(uid)
          .collection('upcoming')
          .doc(widget.event.id)
          .update({
            'progress': currentProgress,
            'subtasks': subtasksMap,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      widget.event.progress = currentProgress;
      widget.onUpdate();
      TutorialTargetRegistry.fireAction();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Failed to update subtasks: $e");
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const nthuPurple = Color(0xFF7E22CE);
    int completed = widget.subtasks.where((s) => s.completed).length;
    int total = widget.subtasks.length;
    int progress = total > 0
        ? ((completed / total) * 100).round()
        : 0; // Kemajuan default 0 jika belum ada subtask (bukan priorityScore)

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            key: TutorialTargetRegistry.get('subtask-modal-content'),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: SingleChildScrollView(
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
                        Text(
                          widget.event.title,
                          maxLines: 3, // Allow an extra line just in case
                          style: const TextStyle(
                            fontSize: 28, // ⬆️ INCREASED from 24
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: Colors.black,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('dd MMMM yyyy').format(widget.event.dueDate).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, // ⬆️ INCREASED from 10
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 2.0, // Wider tracking
                          ),
                        ),
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
                        color: _isCloseHovered
                            ? Colors.grey.shade200
                            : Colors.grey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: _isCloseHovered
                              ? Colors.black
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "TOTAL PROGRESS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "$progress%",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.event.color,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              if (widget.event.summary != null &&
                  widget.event.summary!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    // SMART EXTRACTION: Grabs the very last number in the summary string!
                    final matches = RegExp(r'\d+').allMatches(widget.event.summary!);
                    final scoreNumber = matches.isNotEmpty ? matches.last.group(0)! : "N/A";
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // ⬇️ REDUCED padding
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16), // Slightly tighter radius
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PRIORITY SCORE",
                                style: TextStyle(
                                  fontSize: 9, // ⬇️ REDUCED
                                  fontWeight: FontWeight.w900,
                                  color: Colors.purple.shade400,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scoreNumber,
                                style: const TextStyle(
                                  fontSize: 24, // ⬇️ REDUCED from 28
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7E22CE),
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.purple.shade300,
                                size: 20, // ⬇️ Slightly smaller icon
                              ),
                              tooltip: "",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => PriorityDetailPopup(
                                    summary: widget.event.summary!,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ],
              const SizedBox(height: 24),
              Row(
                key: TutorialTargetRegistry.get('subtask-add-row'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _subtaskCtrl,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: "Add a subtask...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
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
                        height: 48,
                        width: 56,
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
                            side: BorderSide(
                              color: _isAddHovered
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                        tutorialKey: index == widget.subtasks.length - 1
                            ? TutorialTargetRegistry.get('subtask-new-item')
                            : null,
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
                child: SizedBox(
                  key: TutorialTargetRegistry.get('subtask-update-btn'),
                  width: double.infinity,
                  height: 52,
                  child: AnimatedScale(
                    scale: _isUpdateHovered ? 1.02 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isUpdating
                            ? null
                            : () => _saveToFirestore(progress),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nthuPurple,
                          elevation: _isUpdateHovered ? 10 : 0,
                          shadowColor: nthuPurple.withOpacity(0.4),
                          side: BorderSide(
                            color: _isUpdateHovered
                                ? Colors.white.withOpacity(0.85)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "UPDATE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractiveSubtaskRow extends StatefulWidget {
  final Key? tutorialKey;
  final Subtask subtask;
  final VoidCallback onToggle;

  const _InteractiveSubtaskRow({
    Key? key,
    this.tutorialKey,
    required this.subtask,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<_InteractiveSubtaskRow> createState() => _InteractiveSubtaskRowState();
}

class _InteractiveSubtaskRowState extends State<_InteractiveSubtaskRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            key: widget.tutorialKey,
            child: AnimatedScale(
              scale: _isHovered ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isHovered ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHovered
                        ? Colors.grey.shade200
                        : Colors.transparent,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.subtask.completed
                            ? Colors.green
                            : Colors.white,
                        border: Border.all(
                          color: widget.subtask.completed
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: widget.subtask.completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: DefaultTextStyle.of(
                            context,
                          ).style.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.subtask.completed
                              ? Colors.grey
                              : Colors.black87,
                          decoration: widget.subtask.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        child: Text(widget.subtask.text),
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