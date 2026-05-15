import 'package:flutter/material.dart';
import '../utilities/data.dart';

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
  String? _error;

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = "Event Title cannot be empty");
      return;
    }
    if (_selectedDate == null) {
      setState(() => _error = "Please select a date");
      return;
    }
    widget.onSave(_titleCtrl.text.trim(), _selectedDate!, _subtasks);
    Navigator.pop(context);
  }

  // Custom Date Formatting
  String _formatSimpleDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_box_rounded, color: nthuPurple, size: 28),
                  const SizedBox(width: 8),
                  const Text("New TODO", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 24),
              const Text("EVENT TITLE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  hintText: "ex. Probability Extra Assignment",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              const Text("DUE DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
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
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    _selectedDate != null ? _formatSimpleDate(_selectedDate!) : "Select Date",
                    style: TextStyle(fontWeight: FontWeight.bold, color: _selectedDate != null ? Colors.black : Colors.grey),
                  ),
                ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskCtrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        hintText: "Add subtask...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) {
                        if (_subtaskCtrl.text.trim().isNotEmpty) {
                          setState(() { _subtasks.add(_subtaskCtrl.text.trim()); _subtaskCtrl.clear(); });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (_subtaskCtrl.text.trim().isNotEmpty) {
                        setState(() { _subtasks.add(_subtaskCtrl.text.trim()); _subtaskCtrl.clear(); });
                      }
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: nthuPurple, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  )
                ],
              ),
              const SizedBox(height: 16),
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
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
                  Expanded(flex: 2, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: nthuPurple, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}