import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';
import 'tutorial.dart';

class CalendarWidget extends StatefulWidget {
  final DateTime currentDate;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  // CHANGED: Now returns the calculated new DateTime instead of an int (+1/-1)
  final Function(DateTime) onNavigate; 

  const CalendarWidget({
    Key? key,
    required this.currentDate,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onNavigate,
  }) : super(key: key);

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  bool _showFullCalendar = false;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    TutorialTargetRegistry.forceCalendarWeekView = () {
      if (mounted && _showFullCalendar) {
        setState(() {
          _showFullCalendar = false; 
        });
      }
    };
  }

  // Helper: Format date as YYYY-MM-DD
  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Handle Context-Aware Navigation (Week vs Month)
  void _handleNavigation(int step) {
    DateTime newDate;
    DateTime cleanDate = DateUtils.dateOnly(widget.currentDate);
    if (_showFullCalendar) {
      newDate = DateTime(cleanDate.year, cleanDate.month + step, 1);
    } else {
      newDate = DateTime(
        cleanDate.year, 
        cleanDate.month, 
        cleanDate.day + (7 * step)
      );
    }
    widget.onNavigate(newDate);
  }

  // Get Priority Dots for a specific date
  Widget _buildEventDots(DateTime date, bool isSelected) {
    final key = _formatDateKey(date);
    final events = initialCalendarEvents[key] ?? [];
    if (events.isEmpty) return const SizedBox(height: 14);

    // Sort by priority (Exam > Todo > Others)
    int getPriority(String type) {
      if (type.toLowerCase().contains('exam')) return 1;
      if (type.toLowerCase() == 'todo') return 3;
      return 2;
    }

    final sortedEvents = List<AppEvent>.from(events)
      ..sort((a, b) => getPriority(a.type).compareTo(getPriority(b.type)));

    final displayEvents = sortedEvents.take(3).toList();
    final extra = events.length > 3 ? events.length - 3 : 0;

    return SizedBox(
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: displayEvents.map((e) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : e.color,
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
          if (extra > 0)
            Text(
              "+$extra",
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : nthuPurple.withOpacity(0.6),
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  // Generate Week View Days
  List<DateTime> _getWeekDays() {
    DateTime cleanDate = DateUtils.dateOnly(widget.currentDate);
    int offset = widget.currentDate.weekday % 7;
    
    // FIX: Safely calculate Sunday (Start of Week)
    DateTime startOfWeek = DateTime(
      cleanDate.year, 
      cleanDate.month, 
      cleanDate.day - offset
    );

    // Generate the 7 days of the week explicitly
    return List.generate(7, (index) => DateTime(
      startOfWeek.year, 
      startOfWeek.month, 
      startOfWeek.day + index
    ));
  }

  // Generate Month View Days (Including padding for previous/next month)
  List<DateTime?> _getMonthDays() {
    final firstDayOfMonth = DateTime(widget.currentDate.year, widget.currentDate.month, 1);
    final lastDayOfMonth = DateTime(widget.currentDate.year, widget.currentDate.month + 1, 0);
    
    List<DateTime?> days = [];
    // Padding before the 1st
    for (int i = 0; i < firstDayOfMonth.weekday % 7; i++) {
      days.add(null);
    }
    // Days in month
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(widget.currentDate.year, widget.currentDate.month, i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final String currentMonthYear = DateFormat('MMMM yyyy').format(widget.currentDate);

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
        children: [
          // Header (Icon & Toggle Button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: Colors.teal.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Calendar",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ],
              ),
              OutlinedButton(
                key: TutorialTargetRegistry.get('calendar-full-view-btn'),
                onPressed: () {
                  setState(() => _showFullCalendar = !_showFullCalendar);
                  TutorialTargetRegistry.fireAction();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: nthuPurple.withOpacity(0.1)),
                  backgroundColor: Colors.grey.shade50,
                ),
                child: _showFullCalendar 
                  ? const Icon(Icons.close_rounded, size: 16, color: nthuPurple)
                  : const Text(
                      "FULL VIEW",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: nthuPurple, letterSpacing: 1.5),
                    ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // Navigation Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _handleNavigation(-1), // Updated
                icon: Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  currentMonthYear,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
              IconButton(
                onPressed: () => _handleNavigation(1), // Updated
                icon: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar Grid (Animated Week vs Month)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showFullCalendar ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildWeekView(),
            secondChild: _buildMonthView(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    final weekDays = _getWeekDays();
    final today = DateTime.now();

    return GestureDetector(
      key: TutorialTargetRegistry.get('calendar-week-view'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.primaryDelta!;
      },
      onHorizontalDragEnd: (details) {
        if (_dragDistance > 40 || details.primaryVelocity! > 300) {
          _handleNavigation(-1); 
        } else if (_dragDistance < -40 || details.primaryVelocity! < -300) {
          _handleNavigation(1);
        }
        _dragDistance = 0;
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekDays.map((date) {
            final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
            final isToday = DateUtils.isSameDay(date, today);

            return GestureDetector(
              onTap: () {
                widget.onDateSelected(date);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? nthuPurple : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: isToday && !isSelected
                      ? Border.all(color: nthuPurple, width: 2)
                      : Border.all(color: isSelected ? nthuPurple : Colors.grey.shade50, width: 2),
                  boxShadow: isSelected
                      ? [BoxShadow(color: nthuPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                      : [],
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : (isToday ? nthuPurple : Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${date.day}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildEventDots(date, isSelected),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthView() {
    final monthDays = _getMonthDays();
    final today = DateTime.now();
    final weekLabels = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekLabels.map((l) => SizedBox(
              width: 36,
              child: Text(
                l,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final date = monthDays[index];
              if (date == null) return const SizedBox();

              final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
              final isToday = DateUtils.isSameDay(date, today);

              return GestureDetector(
                onTap: () {
                  widget.onDateSelected(date);
                  
                  // ── ADD THIS: Tell the tutorial the user clicked the 21st in Month View! ──
                  if (date.day == 21) {
                    TutorialTargetRegistry.fireAction();
                  }
                },
                child: AnimatedContainer(
                  key: (_showFullCalendar && date.day == 21) ? TutorialTargetRegistry.get('calendar-day-21') : null,
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? nthuPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isToday && !isSelected ? Border.all(color: nthuPurple, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          // UPDATED: Make the day number purple if it's today
                          color: isSelected ? Colors.white : (isToday ? nthuPurple : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildEventDots(date, isSelected),
                    ],
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