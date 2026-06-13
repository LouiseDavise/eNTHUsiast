import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// ── 1. GLOBAL REGISTRY ───────────────────────────────────────────────────────
class TutorialTargetRegistry {
  static final Map<String, GlobalKey> _keys = {};
  static GlobalKey get(String id) {
    _keys.putIfAbsent(id, () => GlobalKey());
    return _keys[id]!;
  }

  static String? activeTargetId;
  static bool activeStepIsSwipeOnly = false;

  static VoidCallback? onActionTriggered;
  static void fireAction({String? sourceId}) {
    if (sourceId != null && sourceId != activeTargetId) return;
    onActionTriggered?.call();
  }

  static bool shouldSuppressTap(String targetId) {
    return activeStepIsSwipeOnly && activeTargetId == targetId;
  }

  static VoidCallback? forceBulletinOpen;
  static VoidCallback? forceCalendarWeekView;
  static VoidCallback? forceCalendarToJune;
}

// ── 2. TUTORIAL ACTIONS & MODELS ─────────────────────────────────────────────
enum TutorialAction {
  actionTrigger,
  button,
  waitForDisappear,
  waitForNextAppear,
}

class TutorialStep {
  final String targetId;
  final String title;
  final String content;
  final TutorialAction action;
  final double padding;
  final double borderRadius;
  final bool swipeOnly;

  const TutorialStep({
    required this.targetId,
    required this.title,
    required this.content,
    required this.action,
    this.padding = 16.0,
    this.borderRadius = 24.0,
    this.swipeOnly = false,
  });
}

// ── 3. CORE OVERLAY WIDGET ───────────────────────────────────────────────────
class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const TutorialOverlay({
    Key? key,
    required this.onComplete,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  int _currentStep = 0;
  Rect? _highlightRect;
  Rect? _lastHighlightRect;
  Timer? _positionTimer;
  bool _isAdvancing = false;

  String? _feedbackTitle;
  String? _feedbackContent;
  Completer<void>? _feedbackCompleter;

  late AnimationController _pulseController;

  late final List<TutorialStep> _steps = const [
    TutorialStep(
      targetId: 'bulletin-board-card',
      title: 'Bulletin Board',
      content: 'Swipe left or right to see news.',
      action: TutorialAction.actionTrigger,
      padding: 0,
      borderRadius: 30,
      swipeOnly: true,
    ),
    TutorialStep(
      targetId: 'calendar-week-view',
      title: 'Week View',
      content: 'Swipe left or right to navigate upcoming weeks.',
      action: TutorialAction.actionTrigger,
      swipeOnly: true,
    ),
    TutorialStep(
      targetId: 'calendar-full-view-btn',
      title: 'Full View',
      content: 'Tap here to expand to full calendar.',
      action: TutorialAction.waitForNextAppear,
      padding: 0,
      borderRadius: 16,
    ),
    TutorialStep(
      targetId: 'calendar-day-21',
      title: 'Check Assignments',
      content: 'Take a look at your schedule for June 21st.',
      action: TutorialAction.waitForNextAppear,
      padding: 4,
      borderRadius: 16,
    ),
    TutorialStep(
      targetId: 'calendar-details-popup-content',
      title: '',
      content: '',
      action: TutorialAction.waitForDisappear,
      padding: 0,
      borderRadius: 48,
    ),
    TutorialStep(
      targetId: 'upcoming-item-0',
      title: 'Upcoming Events',
      content: 'Tap an exam to manage its subtasks and progress.',
      action: TutorialAction.waitForNextAppear,
    ),
    TutorialStep(
      targetId: 'subtask-add-row',
      title: 'Create a subtask',
      content: 'Create a subtask to help finish your goal.',
      action: TutorialAction.waitForNextAppear,
      padding: 0,
      borderRadius: 16,
    ),
    TutorialStep(
      targetId: 'subtask-new-item',
      title: 'Check it as done',
      content: 'Tap the checkbox to mark your new task as complete.',
      action: TutorialAction.actionTrigger,
      padding: -4,
      borderRadius: 24,
    ),
    TutorialStep(
      targetId: 'subtask-update-btn',
      title: 'Save Changes',
      content: 'Tap update to save your changes.',
      action: TutorialAction.waitForDisappear,
      padding: 0,
      borderRadius: 16,
    ),
    TutorialStep(
      targetId: 'upcoming-item-0',
      title: 'Clear Completed',
      content: 'Swipe the exam left or right to clear it from the list!',
      action: TutorialAction.actionTrigger,
      swipeOnly: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTargetRegistry.forceBulletinOpen?.call();
      TutorialTargetRegistry.forceCalendarToJune?.call();
      TutorialTargetRegistry.forceCalendarWeekView?.call();
    });

    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _calcTargetPosition(),
    );

    TutorialTargetRegistry.onActionTriggered = () {
      _nextStep();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildOverlayContent(context),
      );
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    TutorialTargetRegistry.onActionTriggered = null;
    TutorialTargetRegistry.activeTargetId = null;
    TutorialTargetRegistry.activeStepIsSwipeOnly = false;

    _pulseController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _rebuildOverlay(VoidCallback fn) {
    if (mounted) {
      setState(fn);
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _calcTargetPosition() {
    if (_currentStep >= _steps.length || _feedbackTitle != null) return;
    if (_isAdvancing) return;

    final stepInfo = _steps[_currentStep];
    final targetKey = TutorialTargetRegistry.get(stepInfo.targetId);
    TutorialTargetRegistry.activeTargetId = stepInfo.targetId;
    TutorialTargetRegistry.activeStepIsSwipeOnly = stepInfo.swipeOnly;

    if (stepInfo.action == TutorialAction.waitForDisappear) {
      if (_highlightRect != null && targetKey.currentContext == null) {
        _nextStep();
        return;
      }
    } else if (stepInfo.action == TutorialAction.waitForNextAppear) {
      if (_currentStep + 1 < _steps.length) {
        final nextKey = TutorialTargetRegistry.get(
          _steps[_currentStep + 1].targetId,
        );
        if (nextKey.currentContext != null) {
          _nextStep();
          return;
        }
      }
    }

    if (targetKey.currentContext == null ||
        !targetKey.currentContext!.mounted) {
      if (_highlightRect != null) _rebuildOverlay(() => _highlightRect = null);
      return;
    }

    final renderObject = targetKey.currentContext!.findRenderObject();

    if (renderObject == null || !renderObject.attached) {
      if (_highlightRect != null) _rebuildOverlay(() => _highlightRect = null);
      return;
    }
    final RenderBox renderBox = renderObject as RenderBox;
    if (!renderBox.hasSize) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    if (_highlightRect != rect) _rebuildOverlay(() => _highlightRect = rect);
  }

  Future<void> _nextStep() async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    _lastHighlightRect = _highlightRect;

    // Delay 1.5s ONLY for specific requested steps (swipes and dynamic changes)
    final needsDelay = [0, 1, 7, 9].contains(_currentStep);

    if (needsDelay) {
      await Future.delayed(const Duration(milliseconds: 1000));
    } else {
      // Tiny 50ms buffer just to let Flutter render the next frame seamlessly
      await Future.delayed(const Duration(milliseconds: 50));
    }

    int nextStepIndex = _currentStep + 1;

    if (nextStepIndex >= _steps.length) {
      await _showFeedback(
        title: "You're all set!",
        content: "Now you're ready to explore on your own! Good luck 😉.",
        onDone: widget.onComplete,
      );
      return;
    }

    if (nextStepIndex == 1) {
      await _showFeedback(
        title: "Great!",
        content: "Now let's take a look at the Calendar feature!",
      );
    } else if (nextStepIndex == 5) {
      await _showFeedback(
        title: "Nice.",
        content: "Next, let's view our upcoming events.",
      );
    }

    if (mounted) {
      _rebuildOverlay(() {
        _currentStep = nextStepIndex;
        _highlightRect = null;
      });

      final nextKey = TutorialTargetRegistry.get(_steps[_currentStep].targetId);

      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && nextKey.currentContext != null) {
          try {
            Scrollable.ensureVisible(
              nextKey.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } catch (_) {}
        }
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _isAdvancing = false;
  }

  Future<void> _skipTutorial() async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    _lastHighlightRect = _highlightRect;

    await _showFeedback(
      title: "You're all set!",
      content: "Now you're ready to explore on your own! Good luck 😉.",
      onDone: widget.onComplete,
    );

    _isAdvancing = false;
  }

  Future<void> _showFeedback({
    required String title,
    String? content,
    VoidCallback? onDone,
  }) async {
    _feedbackCompleter = Completer<void>();

    _rebuildOverlay(() {
      _feedbackTitle = title;
      _feedbackContent = content;
      _highlightRect = null;
    });

    await _feedbackCompleter!.future;

    if (mounted) {
      _rebuildOverlay(() {
        _feedbackTitle = null;
        _feedbackContent = null;
      });
    }

    if (onDone != null) onDone();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildOverlayContent(BuildContext context) {
    if (_feedbackTitle != null) return _buildFeedbackOverlay(context);

    final currentStepInfo = _steps[_currentStep];
    const Color localPurple = Color(0xFF7A1B7B);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseExpansion = _pulseController.value * 8.0;
        final rect = _highlightRect?.inflate(
          currentStepInfo.padding + pulseExpansion,
        );

        final borderWidth = 2.0 + (_pulseController.value * 3.0);
        final borderColor = localPurple.withOpacity(
          0.5 + (_pulseController.value * 0.5),
        );

        return Stack(
          children: [
            ClipPath(
              clipper: HoleClipper(
                holeRect: rect,
                radius: currentStepInfo.borderRadius + (pulseExpansion / 2),
              ),
              child: GestureDetector(
                onTap: () {},
                onPanDown: (_) {},
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('dimming_$_currentStep'),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 3.0, end: 1.2),
                  builder: (context, scaleVal, child) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: scaleVal,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        currentStepInfo.borderRadius + (pulseExpansion / 2),
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
              
            if (rect != null && currentStepInfo.swipeOnly)
            Positioned.fromRect(
              rect: rect,
              child: _SwipeOnlyGuard(),
            ),

            if (_highlightRect != null)
              _buildTooltip(context, currentStepInfo, rect),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackOverlay(BuildContext context) {
    const Color localPurple = Color(0xFF7A1B7B);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    double? top, bottom;

    if (_lastHighlightRect != null) {
      double spaceAbove = _lastHighlightRect!.top;
      double spaceBelow = size.height - _lastHighlightRect!.bottom;

      if (spaceAbove > spaceBelow && spaceAbove > 200) {
        bottom = size.height - _lastHighlightRect!.top + 12;
        double maxBottom = size.height - padding.top - 210;
        if (bottom > maxBottom) bottom = maxBottom;
      } else if (spaceBelow > 200) {
        top = _lastHighlightRect!.bottom + 12;
        double maxTop = size.height - padding.bottom - 210;
        if (top > maxTop) top = maxTop;
      } else {
        top = size.height / 2 - 90;
      }
    } else {
      top = size.height / 2 - 90;
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (_feedbackCompleter != null &&
                !_feedbackCompleter!.isCompleted) {
              _feedbackCompleter!.complete();
            }
          },
          child: TweenAnimationBuilder<double>(
            key: ValueKey('feedback_dimming_$_feedbackTitle'),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 3.0, end: 1.2),
            builder: (context, scaleVal, child) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: scaleVal,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Positioned(
          top: top,
          bottom: bottom,
          left: 0,
          right: 0,
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_feedbackTitle),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
                );
              },
              child: GestureDetector(
                onTap: () {
                  if (_feedbackCompleter != null &&
                      !_feedbackCompleter!.isCompleted) {
                    _feedbackCompleter!.complete();
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: localPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "TUTORIAL GUIDE",
                            style: TextStyle(
                              color: localPurple,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _feedbackTitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (_feedbackContent != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _feedbackContent!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: 0.4 + (_pulseController.value * 0.6),
                              child: Text(
                                "Tap anywhere to continue...",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    TutorialStep stepInfo,
    Rect? targetRect,
  ) {
    if (_currentStep == 4) return const SizedBox.shrink();

    const Color localPurple = Color(0xFF7A1B7B);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    double? top, bottom;

    final int displayIndex = _currentStep < 4 ? _currentStep + 1 : _currentStep;
    final int totalVisibleTips = _steps.length - 1;

    if (targetRect != null) {
      double spaceAbove = targetRect.top;
      double spaceBelow = size.height - targetRect.bottom;

      if (spaceAbove > spaceBelow && spaceAbove > 200) {
        bottom = size.height - targetRect.top + 12;
        double maxBottom = size.height - padding.top - 210;
        if (bottom > maxBottom) bottom = maxBottom;
      } else if (spaceBelow > 200) {
        top = targetRect.bottom + 12;
        double maxTop = size.height - padding.bottom - 210;
        if (top > maxTop) top = maxTop;
      } else {
        top = size.height / 2 - 90;
      }
    } else {
      top = size.height / 2 - 90;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('tooltip_$_currentStep'),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
          );
        },
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: localPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "TIP $displayIndex OF $totalVisibleTips",
                      style: const TextStyle(
                        color: localPurple,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: displayIndex / totalVisibleTips,
                      backgroundColor: localPurple.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        localPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    stepInfo.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),

                  if (stepInfo.action == TutorialAction.button) ...[
                    const SizedBox(height: 16),
                    _InteractiveTutorialButton(
                      text: "NEXT",
                      color: localPurple,
                      onPressed: _nextStep,
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _InteractiveSkipButton(onTap: _skipTutorial),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HoleClipper extends CustomClipper<Path> {
  final Rect? holeRect;
  final double radius;
  HoleClipper({this.holeRect, this.radius = 16});

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (holeRect != null)
      path.addRRect(
        RRect.fromRectAndRadius(holeRect!, Radius.circular(radius)),
      );
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant HoleClipper oldClipper) =>
      oldClipper.holeRect != holeRect || oldClipper.radius != radius;
}

class _InteractiveTutorialButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;

  const _InteractiveTutorialButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_InteractiveTutorialButton> createState() =>
      _InteractiveTutorialButtonState();
}

class _InteractiveTutorialButtonState
    extends State<_InteractiveTutorialButton> {
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
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractiveSkipButton extends StatefulWidget {
  final VoidCallback onTap;
  const _InteractiveSkipButton({required this.onTap});

  @override
  State<_InteractiveSkipButton> createState() => _InteractiveSkipButtonState();
}

class _InteractiveSkipButtonState extends State<_InteractiveSkipButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Skip tutorial",
                style: TextStyle(
                  color: _isHovered
                      ? Colors.grey.shade600
                      : Colors.grey.shade400,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_double_arrow_right_rounded,
                color: _isHovered ? Colors.grey.shade600 : Colors.grey.shade400,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeOnlyGuard extends StatelessWidget {
  const _SwipeOnlyGuard();

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        // Claim taps exclusively — they stop here, never reach the widget below
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (instance) {
            instance.onTap = () {}; // consume silently
          },
        ),
        // Do NOT list any pan/swipe recognizer here.
        // Flutter's arena will see no competing pan claim from this layer,
        // so pan gestures fall through to the real widget underneath.
      },
      behavior: HitTestBehavior.translucent, // still visible to hit testing
      child: const SizedBox.expand(),
    );
  }
}
