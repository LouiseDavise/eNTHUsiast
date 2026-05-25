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

  static VoidCallback? onActionTriggered;
  static void fireAction() {
    onActionTriggered?.call();
  }

  static VoidCallback? forceBulletinOpen;
  static VoidCallback? forceCalendarWeekView;
}

// ── 2. TUTORIAL ACTIONS & MODELS ─────────────────────────────────────────────
enum TutorialAction { 
  swipe,             
  button,            
  waitForDisappear,  
  waitForNextAppear,
  passive // ✅ Action type that relies strictly on dynamic context triggers without a NEXT button
}

class TutorialStep {
  final String targetId;
  final String title;
  final String content;
  final TutorialAction action;
  final double padding;
  final double borderRadius;

  const TutorialStep({
    required this.targetId,
    required this.title,
    required this.content,
    required this.action,
    this.padding = 16.0,
    this.borderRadius = 24.0,
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

class _TutorialOverlayState extends State<TutorialOverlay> {
  OverlayEntry? _overlayEntry;
  int _currentStep = 0;
  Rect? _highlightRect;
  Timer? _positionTimer;
  bool _isAdvancing = false;
  
  String? _feedbackTitle;
  String? _feedbackContent;
  Offset? _dragStart;

  late final List<TutorialStep> _steps = const [
    TutorialStep(
      targetId: 'bulletin-board-card',
      title: 'Bulletin Board',
      content: 'Swipe left or right to see news.',
      action: TutorialAction.swipe,
      padding: 0,
      borderRadius: 30,
    ),
    TutorialStep(
      targetId: 'calendar-week-view',
      title: 'Week View',
      content: 'Swipe left or right to navigate upcoming days.',
      action: TutorialAction.swipe,
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
      content: 'Tap the 21st! The dots below the dates indicate assignments and their priority.',
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
      content: 'Tap here or the + sign to add a new subtask.',
      action: TutorialAction.waitForNextAppear, 
      padding: 0,
      borderRadius: 16,
    ),
    TutorialStep(
      targetId: 'subtask-new-item',
      title: 'Check it as done',
      content: 'Tap the checkbox to mark your new task as complete.',
      action: TutorialAction.passive, // ✅ Set to passive to remove manual next button constraint
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
      action: TutorialAction.swipe,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // ✅ Enforce correct UI layout state right before the tutorial starts tracking positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTargetRegistry.forceBulletinOpen?.call();
      TutorialTargetRegistry.forceCalendarWeekView?.call();
    });

    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
    _positionTimer = Timer.periodic(const Duration(milliseconds: 30), (_) => _calcTargetPosition());
    
    TutorialTargetRegistry.onActionTriggered = () {
      _nextStep();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayEntry = OverlayEntry(builder: (context) => _buildOverlayContent(context));
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    });
  }
  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointerEvent);
    _positionTimer?.cancel();
    TutorialTargetRegistry.onActionTriggered = null;
    
    _overlayEntry?.remove();
    super.dispose();
  }

  void _rebuildOverlay(VoidCallback fn) {
    if (mounted) {
      setState(fn);
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _handlePointerEvent(PointerEvent event) {
    if (_highlightRect == null || _isAdvancing || _feedbackTitle != null) return;
    final stepInfo = _steps[_currentStep];
    
    if (stepInfo.action != TutorialAction.swipe) return;
    if (!_highlightRect!.contains(event.position)) return;

    if (event is PointerDownEvent) {
      _dragStart = event.position;
    } else if (event is PointerMoveEvent) {
      if (_dragStart != null && (event.position.dx - _dragStart!.dx).abs() > 30) {
        _dragStart = null;
        Future.delayed(const Duration(milliseconds: 300), _nextStep);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _dragStart = null;
    }
  }

  void _calcTargetPosition() {
    if (_currentStep >= _steps.length || _feedbackTitle != null) return;
    
    final stepInfo = _steps[_currentStep];
    final targetKey = TutorialTargetRegistry.get(stepInfo.targetId);

    if (stepInfo.action == TutorialAction.waitForDisappear) {
      if (_highlightRect != null && targetKey.currentContext == null) {
         _nextStep();
         return;
      }
    } else if (stepInfo.action == TutorialAction.waitForNextAppear) {
      if (_currentStep + 1 < _steps.length) {
        final nextKey = TutorialTargetRegistry.get(_steps[_currentStep + 1].targetId);
        if (nextKey.currentContext != null) {
           _nextStep();
           return;
        }
      }
    }

    if (targetKey.currentContext == null || !targetKey.currentContext!.mounted) {
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
    
    final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    if (_highlightRect != rect) _rebuildOverlay(() => _highlightRect = rect);
  }

  Future<void> _nextStep() async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    int nextStepIndex = _currentStep + 1;

    if (nextStepIndex >= _steps.length) {
      await _showFeedback(title: "You're all set!", content: "Now you're ready to explore on your own! Good luck 😉.", onDone: widget.onComplete);
      return;
    }

    if (nextStepIndex == 1) {
      await _showFeedback(title: "Great!", content: "Now let's take a look at the Calendar feature!");
    } else if (nextStepIndex == 5) {
      await _showFeedback(title: "Nice.", content: "Next, let's view our upcoming events.");
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
               alignment: 0.5
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

    await _showFeedback(
      title: "You're all set!", 
      content: "Now you're ready to explore on your own! Good luck 😉.", 
      onDone: widget.onComplete
    );

    _isAdvancing = false;
  }

  Future<void> _showFeedback({required String title, String? content, VoidCallback? onDone}) async {
    _rebuildOverlay(() {
      _feedbackTitle = title;
      _feedbackContent = content;
      _highlightRect = null;
    });
    
    await Future.delayed(const Duration(milliseconds: 2500));
    
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
    final rect = _highlightRect?.inflate(currentStepInfo.padding);

    return Stack(
      children: [
        ClipPath(
          clipper: HoleClipper(holeRect: rect, radius: currentStepInfo.borderRadius),
          child: GestureDetector(
            onTap: () {}, 
            onPanDown: (_) {}, 
            child: Container(
              color: Colors.black.withOpacity(0.70), 
              width: double.infinity, 
              height: double.infinity
            ),
          ),
        ),

        if (rect != null)
          Positioned.fromRect(
            rect: rect,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(currentStepInfo.borderRadius), 
                  border: Border.all(color: localPurple, width: 4)
                ),
              ),
            ),
          ),

        // ✅ Intercepts and blocks all click/tap gestures completely over the targets on swipe steps
        // This stops users from accidentally tapping the bulletin or week view calendar cards, 
        // while perfectly allowing the underlying horizontal scroll view drag recognition to execute.
        if (rect != null && currentStepInfo.action == TutorialAction.swipe)
          Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, 
            ),
          ),

        _buildTooltip(context, currentStepInfo, rect),
      ],
    );
  }

  Widget _buildFeedbackOverlay(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {}, 
          child: Container(color: Colors.black.withOpacity(0.70), width: double.infinity, height: double.infinity)
        ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 290), 
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text("TIP", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0)),
                  ),
                  const SizedBox(height: 16),
                  Text(_feedbackTitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black)),
                  if (_feedbackContent != null) ...[
                    const SizedBox(height: 10),
                    Text(_feedbackContent!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                  ]
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(BuildContext context, TutorialStep stepInfo, Rect? targetRect) {
    if (_currentStep == 4) {
      return const SizedBox.shrink();
    }

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
      top: top, bottom: bottom, left: 0, right: 0,
      child: Center( 
        child: Container(
          constraints: const BoxConstraints(maxWidth: 290), 
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: localPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("TIP $displayIndex OF $totalVisibleTips", style: const TextStyle(color: localPurple, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0)),
                ),
                const SizedBox(height: 16),
                Text(
                  stepInfo.title, 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black)
                ),
                const SizedBox(height: 10),
                Text(
                  stepInfo.content, 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)
                ),
                
                if (stepInfo.action == TutorialAction.button) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: localPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("NEXT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ] else ...[
                   const SizedBox(height: 14),
                   Align(
                     alignment: Alignment.centerRight,
                     child: GestureDetector(
                       onTap: _skipTutorial,
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text("Skip tutorial", style: TextStyle(color: Colors.grey.shade400, fontSize: 12, decoration: TextDecoration.underline)),
                           const SizedBox(width: 4),
                           Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.grey.shade400, size: 14),
                         ],
                       ),
                     ),
                   )
                ]
              ],
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
    if (holeRect != null) {
      path.addRRect(RRect.fromRectAndRadius(holeRect!, Radius.circular(radius)));
    }
    path.fillType = PathFillType.evenOdd; 
    return path;
  }

  @override
  bool shouldReclip(covariant HoleClipper oldClipper) => oldClipper.holeRect != holeRect || oldClipper.radius != radius;
}