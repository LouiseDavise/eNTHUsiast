import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utilities/models.dart';
import 'tutorial.dart';
import 'upcoming.dart';

class AddTaskPopup extends StatefulWidget {
  const AddTaskPopup({Key? key}) : super(key: key);

  @override
  State<AddTaskPopup> createState() => _AddTaskPopupState();
}

class _AddTaskPopupState extends State<AddTaskPopup> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subtaskCtrl = TextEditingController();
  DateTime? _selectedDate;
  List<String> _subtasks = [];
  String? _titleError;
  String? _dateError;
  bool _isSaving = false; // Added to prevent double-clicks

  void _save() async {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty
          ? "Event Title cannot be empty"
          : null;
      _dateError = _selectedDate == null ? "Please select a date" : null;
    });

    if (_titleError != null || _dateError != null) return;

    setState(() => _isSaving = true);

    try {
      final String taskId = UniqueKey().toString();
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      // 3. Safely extract it as a string
      if (uid == null) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: User not logged in. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Stop the save process completely
      }

      // 2. Save directly to Firestore so it persists!
      await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(uid)
          .collection('upcoming')
          .doc(taskId)
          .set({
            'id': taskId,
            'title': _titleCtrl.text.trim(),
            'code': 'TODO',
            'time': '23:59',
            'type': 'todo',
            'location': 'Online',
            'progress': 0,
            'dueDate': Timestamp.fromDate(_selectedDate!),
            'subtasks':
                _subtasks, // Array of strings saves perfectly to Firestore
            'status': 'Incomplete',
            'timestamp': FieldValue.serverTimestamp(),
          });

      // 3. Create the local object (Updated to include subtasks)
      final newTodoTask = AppEvent(
        id: taskId,
        title: _titleCtrl.text.trim(),
        code: 'TODO',
        time: '23:59',
        type: 'todo',
        color: UpcomingTasksWidget.getColorForType('todo'),
        location: 'Online',
        progress: 0,
        dueDate: _selectedDate!,
        subtasks: _subtasks
            .map(
              (text) => Subtask(
                id: UniqueKey().toString(),
                text: text,
                completed: false,
              ),
            )
            .toList(),
      );

      // Note: Since upcoming.dart listens to a Firestore stream, the UI will
      // automatically update when the database changes, but we leave this here
      // for instant feedback.
      UpcomingTasksWidget.tasksNotifier.value = [
        ...UpcomingTasksWidget.tasksNotifier.value,
        newTodoTask,
      ];

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Failed to save task: $e");
      setState(() => _isSaving = false);
      // Optional: Show error snackbar here
    }
  }

  String _formatSimpleDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          key: TutorialTargetRegistry.get('add-task-popup'),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.check_box_outlined,
                      color: Color(0xFF7E22CE),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "New TODO",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title Input
                Text(
                  "EVENT TITLE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: "ex. Probability Extra Assignment",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: _titleError != null
                            ? BorderSide(color: Colors.red.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: _titleError != null
                            ? BorderSide(color: Colors.red.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: _titleError != null
                            ? BorderSide(color: Colors.red.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                if (_titleError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _titleError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Date Picker
                Text(
                  "DUE DATE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: _dateError != null
                          ? Border.all(color: Colors.red.shade400, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? _formatSimpleDate(_selectedDate!)
                              : "dd/mm/yyyy",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedDate != null
                                ? Colors.black87
                                : Colors.grey.shade400,
                            fontSize: 15,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_dateError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _dateError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Subtasks Input
                Text(
                  "SUBTASKS (OPTIONAL)",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                          controller: _subtaskCtrl,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            hintText: "ex. Review Ch. 1",
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
                              setState(() {
                                _subtasks.add(_subtaskCtrl.text.trim());
                                _subtaskCtrl.clear();
                              });
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
                            setState(() {
                              _subtasks.add(_subtaskCtrl.text.trim());
                              _subtaskCtrl.clear();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E22CE),
                          padding: EdgeInsets.zero,
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
                  ],
                ),
                const SizedBox(height: 16),

                // Subtasks List
                ..._subtasks.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFF7E22CE),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _subtasks.removeAt(e.key)),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "CANCEL",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7E22CE),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "SAVE",
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
