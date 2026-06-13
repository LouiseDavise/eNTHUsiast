import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/models.dart';
import 'tutorial.dart';
import 'upcoming.dart'; 
import 'day_details_popup.dart'; // Added the missing import for the popup!

class CalendarWidget extends StatefulWidget {
  final DateTime currentDate;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
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

class _CalendarWidgetState extends State<CalendarWidget>
    with TickerProviderStateMixin {
  bool _showFullCalendar = false;
  double _dragDistance = 0;

  // --- Cascading crossfade animation ---
  late AnimationController _swipeController;

  // direction: +1 = forward (next week), -1 = backward (prev week)
  // Forward  → old cells drift UP   + fade out; new cells rise from BELOW + fade in
  // Backward → old cells drift DOWN + fade out; new cells fall from ABOVE + fade in
  int _swipeDirection = 1;

  // Snapshot of the week being animated OUT (filled when animation starts)
  List<DateTime>? _outgoingWeekDays;

  // Live drag offset (fraction of widget width, for finger-follow feedback)
  double _dragFraction = 0.0;

  // Whether a programmatic swipe animation is running
  bool _animating = false;

  @override
  void initState() {
    super.initState();

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    UpcomingTasksWidget.tasksNotifier.addListener(_onTasksUpdated);

    TutorialTargetRegistry.forceCalendarWeekView = () {
      if (mounted && _showFullCalendar) {
        setState(() {
          _showFullCalendar = false; 
        });
      }
    };
    
    TutorialTargetRegistry.forceCalendarToJune = () {
      if (mounted) {
        final currentYear = DateTime.now().year;
        if (widget.currentDate.month != 6) {
          widget.onNavigate(DateTime(currentYear, 6, 21));
        }
      }
    };
  }

  @override
  void dispose() {
    _swipeController.dispose();
    UpcomingTasksWidget.tasksNotifier.removeListener(_onTasksUpdated);
    super.dispose();
  }

  void _onTasksUpdated() {
    if (mounted) setState(() {});
  }

  /// Captures outgoing week snapshot and sets direction before animating.
  void _prepareAnimation({required int direction}) {
    _swipeDirection = direction;
    _outgoingWeekDays = _computeWeekDays(widget.currentDate);
  }

  /// Triggers the cascading crossfade animation then commits navigation.
  Future<void> _handleNavigationAnimated(int step) async {
    if (_animating || _showFullCalendar) {
      _handleNavigation(step);
      return;
    }

    _prepareAnimation(direction: step);
    _swipeController.reset();
    setState(() {
      _animating = true;
      _dragFraction = 0;
    });

    await _swipeController.forward();

    widget.onNavigate(_nextDate(step));
    _swipeController.reset();

    setState(() {
      _animating = false;
      _outgoingWeekDays = null;
    });
  }

  DateTime _nextDate(int step) {
    DateTime cleanDate = DateUtils.dateOnly(widget.currentDate);
    return DateTime(cleanDate.year, cleanDate.month, cleanDate.day + (7 * step));
  }

  List<DateTime> _computeWeekDays(DateTime anchorDate) {
    final cleanDate = DateUtils.dateOnly(anchorDate);
    final int offset = anchorDate.weekday % 7;
    final startOfWeek = DateTime(cleanDate.year, cleanDate.month, cleanDate.day - offset);
    return List.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );
  }

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

  List<DateTime?> _getMonthDays() {
    final firstDayOfMonth = DateTime(widget.currentDate.year, widget.currentDate.month, 1);
    final lastDayOfMonth = DateTime(widget.currentDate.year, widget.currentDate.month + 1, 0);
    
    List<DateTime?> days = [];
    for (int i = 0; i < firstDayOfMonth.weekday % 7; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(widget.currentDate.year, widget.currentDate.month, i));
    }
    return days;
  }

  List<AppEvent> _getEventsForDate(DateTime date) {
    return UpcomingTasksWidget.tasksNotifier.value
        .where((e) => DateUtils.isSameDay(e.dueDate, date))
        .toList();
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
              _InteractiveToggleButton(
                isFullView: _showFullCalendar,
                onPressed: () {
                  setState(() => _showFullCalendar = !_showFullCalendar);
                },
              )
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InteractiveArrowButton(
                icon: Icons.chevron_left_rounded,
                onPressed: () => _handleNavigationAnimated(-1),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  currentMonthYear,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
              _InteractiveArrowButton(
                icon: Icons.chevron_right_rounded,
                onPressed: () => _handleNavigationAnimated(1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            sizeCurve: Curves.easeOutBack,
            crossFadeState: _showFullCalendar ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildWeekView(),
            secondChild: _buildMonthView(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    return GestureDetector(
      key: TutorialTargetRegistry.get('calendar-week-view'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        if (_animating) return;
        _dragDistance += details.primaryDelta!;
        setState(() {
          _dragFraction = _dragDistance / context.size!.width;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_animating) return;
        final velocity = details.primaryVelocity ?? 0;
        if (_dragDistance > 40 || velocity > 300) {
          _dragDistance = 0;
          _dragFraction = 0;
          _handleNavigationAnimated(-1);
          TutorialTargetRegistry.fireAction();
        } else if (_dragDistance < -40 || velocity < -300) {
          _dragDistance = 0;
          _dragFraction = 0;
          _handleNavigationAnimated(1);
          TutorialTargetRegistry.fireAction();
        } else {
          setState(() {
            _dragDistance = 0;
            _dragFraction = 0;
          });
        }
      },
      child: AnimatedBuilder(
        animation: _swipeController,
        builder: (context, _) {
          final t = _swipeController.value; // 0.0 → 1.0

          if (_animating && _outgoingWeekDays != null) {
            final incomingWeekDays = _computeWeekDays(_nextDate(_swipeDirection));
            return _buildCascadingRows(
              outgoing: _outgoingWeekDays!,
              incoming: incomingWeekDays,
              t: t,
              direction: _swipeDirection,
            );
          }

          // Idle / live-drag: subtle horizontal + vertical follow
          final absDrag = _dragFraction.abs().clamp(0.0, 1.0);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(_dragFraction * MediaQuery.of(context).size.width * 0.4, 0.0)
              ..scale(1.0 - absDrag * 0.02),
            child: _buildWeekRow(_computeWeekDays(widget.currentDate)),
          );
        },
      ),
    );
  }

  /// Builds two overlaid rows where each of the 7 cells animates with a
  /// staggered delay — creating the cascading waterfall crossfade effect.
  Widget _buildCascadingRows({
    required List<DateTime> outgoing,
    required List<DateTime> incoming,
    required double t,           // controller value 0→1
    required int direction,      // +1 forward, -1 backward
  }) {
    const int cellCount = 7;
    // Each cell's animation window within the full 0→1 timeline.
    // They overlap so the cascade isn't too slow.
    const double cellDuration = 0.55; // fraction of total each cell takes
    const double staggerStep = (1.0 - cellDuration) / (cellCount - 1);

    // Vertical drift direction: forward→ old drifts up, new comes from below
    //                           backward→ old drifts down, new comes from above
    final double driftSign = direction > 0 ? -1.0 : 1.0;
    const double driftPx = 14.0; // max vertical travel in logical pixels

    Widget buildCell(DateTime date, int cellIndex, {required bool isOut}) {
      // Map t into this cell's [0,1] local progress
      final cellStart = cellIndex * staggerStep;
      final rawLocal = (t - cellStart) / cellDuration;
      final local = rawLocal.clamp(0.0, 1.0);

      // Apply ease curves
      final easedLocal = Curves.easeInOutCubic.transform(local);

      double opacity;
      double dy;

      if (isOut) {
        // Fade OUT: opacity 1→0, drifts in driftSign direction
        opacity = (1.0 - easedLocal).clamp(0.0, 1.0);
        dy = driftSign * driftPx * easedLocal;
      } else {
        // Fade IN: opacity 0→1, arrives from opposite direction
        opacity = easedLocal.clamp(0.0, 1.0);
        dy = -driftSign * driftPx * (1.0 - easedLocal);
      }

      final today = DateTime.now();
      final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
      final isToday = DateUtils.isSameDay(date, today);
      final dailyEvents = _getEventsForDate(date);

      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, dy),
          child: _InteractiveDayCell(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            events: dailyEvents,
            onTap: () => widget.onDateSelected(date),
          ),
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(cellCount, (i) {
          return Stack(
            alignment: Alignment.center,
            children: [
              buildCell(outgoing[i], i, isOut: true),
              buildCell(incoming[i], i, isOut: false),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeekRow(List<DateTime> weekDays) {
    final today = DateTime.now();

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((date) {
          final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
          final isToday = DateUtils.isSameDay(date, today);
          final dailyEvents = _getEventsForDate(date);

          return _InteractiveDayCell(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            events: dailyEvents,
            onTap: () {
              widget.onDateSelected(date);
              showDialog(
                context: context,
                builder: (context) => DayDetailsPopup(date: date, events: dailyEvents),
              );
            },
          );
        }).toList(),
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
              final dailyEvents = _getEventsForDate(date);
              
              final isJune21st = date.day == 21 && date.month == 6;

              return _InteractiveDayCell(
                key: (_showFullCalendar && isJune21st) ? TutorialTargetRegistry.get('calendar-day-21') : null,
                date: date,
                isSelected: isSelected,
                isToday: isToday,
                isMonthView: true,
                events: dailyEvents,
                onTap: () {
                  widget.onDateSelected(date);
                  showDialog(
                    context: context,
                    builder: (context) => DayDetailsPopup(date: date, events: dailyEvents),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InteractiveDayCell extends StatefulWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isMonthView;
  final List<AppEvent> events;
  final VoidCallback onTap;

  const _InteractiveDayCell({
    Key? key,
    required this.date,
    required this.isSelected,
    required this.isToday,
    this.isMonthView = false,
    required this.events,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_InteractiveDayCell> createState() => _InteractiveDayCellState();
}

class _InteractiveDayCellState extends State<_InteractiveDayCell> {
  bool _isHovered = false;
  bool _isPressed = false;

  Widget _buildEventDots() {
    if (widget.events.isEmpty) return const SizedBox(height: 14);

    int getPriority(String type) {
      if (type.toLowerCase().contains('exam')) return 1;
      if (type.toLowerCase() == 'todo') return 3;
      return 2;
    }

    final sortedEvents = List<AppEvent>.from(widget.events)
      ..sort((a, b) => getPriority(a.type).compareTo(getPriority(b.type)));

    final displayEvents = sortedEvents.take(3).toList();
    final extra = widget.events.length > 3 ? widget.events.length - 3 : 0;

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
                  color: widget.isSelected ? Colors.white : e.color,
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
                color: widget.isSelected ? Colors.white : const Color(0xFF7E22CE).withOpacity(0.6),
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const nthuPurple = Color(0xFF7E22CE);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : (_isHovered && !widget.isSelected ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: widget.isMonthView 
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: widget.isSelected ? nthuPurple : (_isHovered ? nthuPurple.withOpacity(0.05) : Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                  border: widget.isToday && !widget.isSelected ? Border.all(color: nthuPurple, width: 2) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${widget.date.day}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: widget.isSelected ? Colors.white : (widget.isToday ? nthuPurple : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildEventDots(),
                  ],
                ),
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: widget.isSelected ? nthuPurple : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: widget.isToday && !widget.isSelected
                      ? Border.all(color: nthuPurple, width: 2)
                      : Border.all(color: widget.isSelected ? nthuPurple : (_isHovered ? Colors.grey.shade200 : Colors.grey.shade50), width: 2),
                  boxShadow: widget.isSelected
                      ? [BoxShadow(color: nthuPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
                      : (_isHovered ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))] : []),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(widget.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: widget.isSelected ? Colors.white : (widget.isToday ? nthuPurple : Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${widget.date.day}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: widget.isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildEventDots(),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class _InteractiveToggleButton extends StatefulWidget {
  final bool isFullView;
  final VoidCallback onPressed;

  const _InteractiveToggleButton({required this.isFullView, required this.onPressed});

  @override
  State<_InteractiveToggleButton> createState() => _InteractiveToggleButtonState();
}

class _InteractiveToggleButtonState extends State<_InteractiveToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const nthuPurple = Color(0xFF7E22CE);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: OutlinedButton(
        key: TutorialTargetRegistry.get('calendar-full-view-btn'),
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: _isHovered ? nthuPurple.withOpacity(0.4) : nthuPurple.withOpacity(0.1)),
          backgroundColor: _isHovered ? nthuPurple.withOpacity(0.05) : Colors.grey.shade50,
          animationDuration: const Duration(milliseconds: 200),
        ),
        child: widget.isFullView 
          ? const Icon(Icons.close_rounded, size: 16, color: nthuPurple)
          : const Text(
              "FULL VIEW",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: nthuPurple, letterSpacing: 1.5),
            ),
      ),
    );
  }
}

class _InteractiveArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _InteractiveArrowButton({required this.icon, required this.onPressed});

  @override
  State<_InteractiveArrowButton> createState() => _InteractiveArrowButtonState();
}

class _InteractiveArrowButtonState extends State<_InteractiveArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IconButton(
        onPressed: widget.onPressed,
        icon: AnimatedScale(
          scale: _isHovered ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(widget.icon, color: _isHovered ? Colors.black87 : Colors.grey.shade400),
        ),
      ),
    );
  }
}