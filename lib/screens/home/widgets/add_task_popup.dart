import 'dart:ui';
import 'package:flutter/material.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';
import 'upcoming.dart'; 

class AddTaskPopup extends StatefulWidget {
  final Function(String title, DateTime date, List<String> subtasks) onSave;

  const AddTaskPopup({Key? key, required this.onSave}) : super(key: key);

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

  void _save() {
    setState(() {
      _titleError = _titleCtrl.text.trim().isEmpty ? "Event Title cannot be empty" : null;
      _dateError = _selectedDate == null ? "Please select a date" : null;
    });

    if (_titleError != null || _dateError != null) {
      return;
    }

    final newTodoTask = AppEvent(
      id: UniqueKey().toString(), 
      title: _titleCtrl.text.trim(),
      code: 'TODO',
      time: '23:59',
      type: 'todo', 
      color: UpcomingTasksWidget.getColorForType('todo'), 
      location: 'Online',
      progress: 0,
      dueDate: _selectedDate!,
    );

    UpcomingTasksWidget.tasksNotifier.value = [
      ...UpcomingTasksWidget.tasksNotifier.value,
      newTodoTask,
    ];

    widget.onSave(_titleCtrl.text.trim(), _selectedDate!, _subtasks);
    
    Navigator.pop(context);
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
                    const Icon(Icons.check_box_outlined, color: nthuPurple, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      "New TODO", 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Title Input
                Text("EVENT TITLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      hintText: "ex. Probability Extra Assignment",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), 
                        borderSide: _titleError != null ? BorderSide(color: Colors.red.shade400, width: 1.5) : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), 
                        borderSide: _titleError != null ? BorderSide(color: Colors.red.shade400, width: 1.5) : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), 
                        borderSide: _titleError != null ? BorderSide(color: Colors.red.shade400, width: 1.5) : BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                if (_titleError != null) 
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_titleError!, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(height: 24),
                
                // Date Picker
                Text("DUE DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
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
                      border: _dateError != null ? Border.all(color: Colors.red.shade400, width: 1.5) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null ? _formatSimpleDate(_selectedDate!) : "dd/mm/yyyy",
                          style: TextStyle(fontWeight: FontWeight.bold, color: _selectedDate != null ? Colors.black87 : Colors.grey.shade400, fontSize: 15),
                        ),
                        const Icon(Icons.calendar_today_rounded, color: Colors.black87, size: 20),
                      ],
                    ),
                  ),
                ),
                if (_dateError != null) 
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_dateError!, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                const SizedBox(height: 24),
                
                // Subtasks Input
                Text("SUBTASKS (OPTIONAL)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Row(
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
                            hintText: "ex. Review Ch. 1",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: (_) {
                            if (_subtaskCtrl.text.trim().isNotEmpty) {
                              setState(() { _subtasks.add(_subtaskCtrl.text.trim()); _subtaskCtrl.clear(); });
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
                            setState(() { _subtasks.add(_subtaskCtrl.text.trim()); _subtaskCtrl.clear(); });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nthuPurple, 
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Subtasks List
                ..._subtasks.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: nthuPurple, shape: BoxShape.circle))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      GestureDetector(onTap: () => setState(() => _subtasks.removeAt(e.key)), child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey))
                    ],
                  ),
                )),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text("CANCEL", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _save, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nthuPurple, 
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ), 
                          child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}