import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';
import '../api/bao_bao_ai_api.dart';

class CoursePlannerAiChatDialog extends StatefulWidget {
  final List<PlannerCourse> allCourses;
  final List<PlannerCourse> plannedCourses;

  const CoursePlannerAiChatDialog({
    super.key,
    required this.allCourses,
    required this.plannedCourses,
  });

  @override
  State<CoursePlannerAiChatDialog> createState() =>
      _CoursePlannerAiChatDialogState();
}

class _CoursePlannerAiChatDialogState extends State<CoursePlannerAiChatDialog>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final BaoBaoAiApi _baoBaoAiApi = BaoBaoAiApi();

  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  bool isLoading = false;
  bool showSuggestions = true;

  String speechText =
      "Tell me your ideal semester vibe, and I'll find the perfect classes for you!";
  String lastUserPrompt = '';

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> sendPrompt([String? presetPrompt]) async {
    final text = (presetPrompt ?? _messageController.text).trim();

    if (text.isEmpty || isLoading) {
      return;
    }

    _messageController.clear();

    setState(() {
      isLoading = true;
      showSuggestions = false;
      lastUserPrompt = text;
      speechText = _loadingTextFor(text);
    });

    if (_isSmallTalkOnly(text)) {
      final reply = await _baoBaoAiApi.askBaoBao(text);

      if (!mounted) return;

      setState(() {
        speechText = reply;
        isLoading = false;
        showSuggestions = true;
      });

      return;
    }

    final recommendedIds = await _baoBaoAiApi.askBaoBaoRecommendedCourseIds(
      userMessage: text,
      courseCatalog: _buildCourseCatalogForAi(),
    );

    if (!mounted) return;

    if (recommendedIds.isEmpty) {
      setState(() {
        speechText =
            "Bao-Bao couldn't find matching course cards 🐼 Try adding clearer details like GE, CS core, language, professor name, credits, or time preference.";
        isLoading = false;
        showSuggestions = true;
      });

      return;
    }

    setState(() {
      speechText =
          "Found ${recommendedIds.length} matching course card${recommendedIds.length == 1 ? '' : 's'}! Opening them now ✨";
      isLoading = false;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    Navigator.pop(context, {
      'courseIds': recommendedIds,
      'message': _successMessageFor(text, recommendedIds.length),
    });
  }

  String _successMessageFor(String prompt, int count) {
    final lower = prompt.toLowerCase();

    if (lower.contains('prof') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by')) {
      return 'Here are the courses I found based on the professor name you asked for 🐼';
    }

    if (lower.contains('20') && lower.contains('credit')) {
      return 'Here are the courses I found for your credit plan. I tried to match your GE, CS core, and language requirements ✨';
    }

    if (lower.contains('ge')) {
      return 'Here are the GE-related courses I found for you ✨';
    }

    if (lower.contains('cs') || lower.contains('computer')) {
      return 'Here are the CS-related courses I found for your plan 🐼';
    }

    if (lower.contains('language') ||
        lower.contains('english') ||
        lower.contains('japanese') ||
        lower.contains('chinese')) {
      return 'Here are the language courses I found based on your request 🌸';
    }

    if (lower.contains('morning') || lower.contains('early')) {
      return 'Here are courses that better fit your no-early-morning preference 😴';
    }

    if (lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('light')) {
      return 'Here are some lighter courses that may fit a chill semester 🌿';
    }

    return 'Here are the courses Bao-Bao found based on your request ✨';
  }

  String _loadingTextFor(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('morning') || lower.contains('early')) {
      return 'Filtering out morning courses for you...';
    }

    if (lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('light')) {
      return 'Looking for a lighter and chill schedule...';
    }

    if (lower.contains('credit')) {
      return 'Balancing your credit load...';
    }

    if (lower.contains('prof') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by')) {
      return 'Searching by professor name...';
    }

    if (lower.contains('conflict')) {
      return 'Checking possible schedule conflicts...';
    }

    return 'Bao-Bao is finding real course cards for you...';
  }

  bool _isSmallTalkOnly(String message) {
    final lower = message.toLowerCase().trim();

    final hasCourseHint =
        lower.contains('course') ||
        lower.contains('class') ||
        lower.contains('credit') ||
        lower.contains('schedule') ||
        lower.contains('ge') ||
        lower.contains('core') ||
        lower.contains('elective') ||
        lower.contains('language') ||
        lower.contains('lab') ||
        lower.contains('pe') ||
        lower.contains('cs') ||
        lower.contains('i2p') ||
        lower.contains('oop') ||
        lower.contains('ds') ||
        lower.contains('ai') ||
        lower.contains('math') ||
        lower.contains('english') ||
        lower.contains('japanese') ||
        lower.contains('chinese') ||
        lower.contains('prof') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by') ||
        lower.contains('通識') ||
        lower.contains('必修') ||
        lower.contains('選修') ||
        lower.contains('英文') ||
        lower.contains('日文') ||
        lower.contains('中文') ||
        lower.contains('體育');

    if (hasCourseHint) {
      return false;
    }

    return lower == 'hi' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower.contains('who are you') ||
        lower.contains('what can you do');
  }

  List<Map<String, dynamic>> _buildCourseCatalogForAi() {
    return widget.allCourses.map((course) {
      return {
        'id': course.id,
        'code': course.code,
        'title': course.title,
        'professor': course.professor,
        'credits': course.credits,
        'type': course.type,
        'department': course.department,
        'slotCode': course.slotCode,
        'timeSlot': course.timeSlot,
        'location': course.location,
        'rating': course.rating,
        'limit': course.limit,
        'alreadyPlanned': _isAlreadyPlanned(course),
        'hasConflict': _hasConflict(course),
      };
    }).toList();
  }

  bool _isAlreadyPlanned(PlannerCourse course) {
    return widget.plannedCourses.any(
      (plannedCourse) => plannedCourse.id == course.id,
    );
  }

  bool _hasConflict(PlannerCourse course) {
    for (final plannedCourse in widget.plannedCourses) {
      if (plannedCourse.id == course.id) continue;
      if (plannedCourse.day != course.day) continue;

      final plannedStart = plannedCourse.startSlot;
      final plannedEnd = plannedCourse.startSlot + plannedCourse.duration;

      final courseStart = course.startSlot;
      final courseEnd = course.startSlot + course.duration;

      if (plannedStart < courseEnd && courseStart < plannedEnd) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 7,
                sigmaY: 7,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                22,
                20,
                22,
                math.max(24, bottomInset + 20),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 430,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SpeechBubble(
                        text: speechText,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 6),
                      _BaoBaoAvatar(
                        floatController: _floatController,
                        pulseController: _pulseController,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 28),
                      if (lastUserPrompt.isNotEmpty) ...[
                        _UserPromptPreview(text: lastUserPrompt),
                        const SizedBox(height: 14),
                      ],
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: isLoading
                            ? const SizedBox.shrink()
                            : Column(
                                children: [
                                  _PromptInput(
                                    controller: _messageController,
                                    isLoading: isLoading,
                                    onSend: () => sendPrompt(),
                                  ),
                                  if (showSuggestions) ...[
                                    const SizedBox(height: 14),
                                    _SuggestionChips(
                                      onSelected: sendPrompt,
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 22,
            right: 22,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool isLoading;

  const _SpeechBubble({
    required this.text,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.13),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF7E3291),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CustomPaint(
            size: const Size(30, 14),
            painter: _BubbleTailPainter(),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BaoBaoAvatar extends StatelessWidget {
  final AnimationController floatController;
  final AnimationController pulseController;
  final bool isLoading;

  const _BaoBaoAvatar({
    required this.floatController,
    required this.pulseController,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        floatController,
        pulseController,
      ]),
      builder: (context, child) {
        final floatY = math.sin(floatController.value * math.pi * 2) * 5;
        final scale = isLoading ? 1.0 + (pulseController.value * 0.08) : 1.0;

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF3E8FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E3291).withValues(alpha: 0.22),
                        blurRadius: 38,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE9D5FF),
                      width: 4,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '🐼',
                      style: TextStyle(fontSize: 42),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 4,
                  child: _Sparkle(
                    size: 18,
                    delay: 0,
                    controller: floatController,
                  ),
                ),
                Positioned(
                  top: 26,
                  right: -9,
                  child: _Sparkle(
                    size: 12,
                    delay: 0.25,
                    controller: floatController,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  final double delay;
  final AnimationController controller;

  const _Sparkle({
    required this.size,
    required this.delay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = ((controller.value + delay) % 1.0);
        final opacity = 0.35 + math.sin(value * math.pi) * 0.65;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: size,
            color: const Color(0xFF9333EA),
          ),
        );
      },
    );
  }
}

class _UserPromptPreview extends StatelessWidget {
  final String text;

  const _UserPromptPreview({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      constraints: const BoxConstraints(
        maxWidth: 330,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

class _PromptInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _PromptInput({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.only(
        left: 20,
        right: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              onSubmitted: (_) => onSend(),
              cursorColor: const Color(0xFF7E3291),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tell Bao-Bao what you need...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: isLoading ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isLoading
                    ? const Color(0xFFE9D5FF)
                    : const Color(0xFF7E3291),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _SuggestionChips({
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      _BaoBaoSuggestion(
        label: 'No early mornings please 😴',
        prompt: 'Recommend courses but avoid early morning classes',
      ),
      _BaoBaoSuggestion(
        label: 'Chill and easy classes 🌿',
        prompt: 'Recommend chill and lighter courses for next semester',
      ),
      _BaoBaoSuggestion(
        label: '20 credits plan 🎯',
        prompt:
            'I need 20 credits with 4 GE courses, 2 CS core courses, and 1 language course',
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: suggestions.map((suggestion) {
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onSelected(suggestion.prompt),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              suggestion.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF475569),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BaoBaoSuggestion {
  final String label;
  final String prompt;

  const _BaoBaoSuggestion({
    required this.label,
    required this.prompt,
  });
}