import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/courses_planner_model.dart';
import '../api/bao_bao_ai_api.dart';

enum _BaoBaoStage {
  idle,
  loading,
  success,
  error,
}

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
  late final AnimationController _sparkleController;

  Timer? _loadingTimer;

  _BaoBaoStage stage = _BaoBaoStage.idle;

  String speechText =
      "Tell me what kind of courses you want, and I'll search the real course list for you 🐼";
  String lastUserPrompt = '';

  List<String> loadingMessages = const [];
  int loadingIndex = 0;

  List<String> pendingRecommendedIds = [];
  String? pendingResultMessage;

  bool get isLoading => stage == _BaoBaoStage.loading;
  bool get isSuccess => stage == _BaoBaoStage.success;
  bool get isError => stage == _BaoBaoStage.error;

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

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _messageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  Future<void> sendPrompt([String? presetPrompt]) async {
    final text = (presetPrompt ?? _messageController.text).trim();
    
    FocusScope.of(context).unfocus();

    if (text.isEmpty || isLoading) {
      return;
    }

    _messageController.clear();

    _startLoading(text);

    if (_isSmallTalkOnly(text)) {
      final reply = await _baoBaoAiApi.askBaoBao(text);

      if (!mounted) return;

      _stopLoading();

      setState(() {
        stage = _BaoBaoStage.idle;
        speechText = reply;
      });

      return;
    }

    final recommendedIds = await _baoBaoAiApi.askBaoBaoRecommendedCourseIds(
      userMessage: text,
      courseCatalog: _buildCourseCatalogForAi(),
    );

    if (!mounted) return;

    _stopLoading();

    if (recommendedIds.isEmpty) {
      setState(() {
        stage = _BaoBaoStage.error;
        speechText = _notFoundMessageFor(text);
      });

      return;
    }

    final resultMessage = _successMessageFor(text, recommendedIds.length);

    setState(() {
      stage = _BaoBaoStage.success;
      pendingRecommendedIds = recommendedIds;
      pendingResultMessage = resultMessage;
      speechText = '$resultMessage\n\nTap anywhere to continue ✨';
    });
  }

  void _startLoading(String prompt) {
    _loadingTimer?.cancel();

    final messages = _loadingMessagesFor(prompt);

    setState(() {
      stage = _BaoBaoStage.loading;
      lastUserPrompt = prompt;
      loadingMessages = messages;
      loadingIndex = 0;
      speechText = messages.first;
      pendingRecommendedIds = [];
      pendingResultMessage = null;
    });

    _loadingTimer = Timer.periodic(const Duration(milliseconds: 1050), (_) {
      if (!mounted || !isLoading || loadingMessages.isEmpty) return;

      setState(() {
        loadingIndex = (loadingIndex + 1) % loadingMessages.length;
        speechText = loadingMessages[loadingIndex];
      });
    });
  }

  void _stopLoading() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
  }

  void _continueWithResults() {
    if (!isSuccess || pendingRecommendedIds.isEmpty) {
      return;
    }

    Navigator.pop(context, {
      'courseIds': pendingRecommendedIds,
      'message': pendingResultMessage,
    });
  }

  List<String> _loadingMessagesFor(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('morning') ||
        lower.contains('night') ||
        lower.contains('evening') ||
        lower.contains('afternoon')) {
      return const [
        'Checking the class time slots...',
        'Comparing morning, afternoon, and night schedules...',
        'Removing courses that do not match your time preference...',
        'Almost done finding the best time matches...',
      ];
    }

    if (lower.contains('limit') ||
        lower.contains('capacity') ||
        lower.contains('many students')) {
      return const [
        'Reading course capacity from Firebase...',
        'Sorting courses by enrollment limit...',
        'Looking for classes with enough seats...',
        'Almost done checking course limits...',
      ];
    }

    if (lower.contains('conduct') ||
        lower.contains('taught in') ||
        lower.contains('instruction') ||
        lower.contains('in eng') ||
        lower.contains('in english') ||
        lower.contains('in chinese')) {
      return const [
        'Checking the language of instruction...',
        'Matching your subject with the instruction language...',
        'Filtering out unrelated courses...',
        'Almost done finding the right course cards...',
      ];
    }

    if (lower.contains('prof') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by')) {
      return const [
        'Searching by professor name...',
        'Checking instructor fields from the course list...',
        'Matching professor names carefully...',
        'Almost done finding professor-related courses...',
      ];
    }

    if (lower.contains('credit')) {
      return const [
        'Balancing your credit request...',
        'Splitting the request into course groups...',
        'Checking credits, type, and course category...',
        'Almost done building your course mix...',
      ];
    }

    if (lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('light')) {
      return const [
        'Looking for a lighter semester vibe...',
        'Avoiding courses that look too intense...',
        'Checking credits and schedule friendliness...',
        'Almost done finding chill course options...',
      ];
    }

    return const [
      'Reading your request carefully...',
      'Searching the real Firebase course list...',
      'Filtering by subject, type, time, and language...',
      'Picking the best matching course cards...',
    ];
  }

  String _successMessageFor(String prompt, int count) {
    final courseLabel = _specificCourseLabel(prompt);
    final instructionLanguage = _instructionLanguageLabel(prompt);
    final isOne = count == 1;

    if (courseLabel != null && instructionLanguage != null) {
      return isOne
          ? 'I found a $courseLabel course conducted in $instructionLanguage 🐼'
          : 'I found $count $courseLabel courses conducted in $instructionLanguage 🐼';
    }

    if (courseLabel != null) {
      return isOne
          ? 'I found a $courseLabel course that matches your request 🐼'
          : 'I found $count $courseLabel courses that match your request 🐼';
    }

    if (instructionLanguage != null && _asksForInstructionLanguage(prompt)) {
      return 'I found $count courses conducted in $instructionLanguage 🌐';
    }

    final lower = prompt.toLowerCase();

    if (lower.contains('prof') ||
        lower.contains('teacher') ||
        lower.contains('instructor') ||
        lower.contains('taught by')) {
      return 'I found $count courses based on the professor name you asked for 🐼';
    }

    if (lower.contains('20') && lower.contains('credit')) {
      return 'I found a course mix for your credit plan. I tried to match your GE, CS core, and language requirements ✨';
    }

    if (lower.contains('ge')) {
      return 'I found $count GE-related courses for you ✨';
    }

    if (lower.contains('cs') || lower.contains('computer')) {
      return 'I found $count CS-related courses for your plan 🐼';
    }

    if (_asksForLanguageSubject(prompt)) {
      return 'I found $count language courses based on your request 🌸';
    }

    if (lower.contains('morning') || lower.contains('early')) {
      return 'I found $count courses that better fit your time preference 😴';
    }

    if (lower.contains('easy') ||
        lower.contains('chill') ||
        lower.contains('light')) {
      return 'I found $count lighter courses for a chill semester 🌿';
    }

    return isOne
        ? 'I found a course that matches your request ✨'
        : 'I found $count courses that match your request ✨';
  }

  String _notFoundMessageFor(String prompt) {
    final courseLabel = _specificCourseLabel(prompt);
    final instructionLanguage = _instructionLanguageLabel(prompt);

    if (courseLabel != null && instructionLanguage != null) {
      return "I couldn't find a $courseLabel course conducted in $instructionLanguage 🐼\n\nTry removing the language filter, or ask for similar courses.";
    }

    if (courseLabel != null) {
      return "I couldn't find a matching $courseLabel course 🐼\n\nTry using the full course name, professor name, or another semester.";
    }

    if (instructionLanguage != null && _asksForInstructionLanguage(prompt)) {
      return "I couldn't find matching courses conducted in $instructionLanguage 🐼\n\nTry another subject, department, or time preference.";
    }

    return "Bao-Bao couldn't find matching course cards 🐼\n\nTry adding clearer details like GE, CS core, language, professor name, credits, or time preference.";
  }

  String? _specificCourseLabel(String prompt) {
    final lower = prompt.toLowerCase();

    if (RegExp(r'\bi2p\b').hasMatch(lower) ||
        lower.contains('intro to programming') ||
        lower.contains('introduction to programming')) {
      return 'I2P';
    }

    if (RegExp(r'\bds\b').hasMatch(lower) ||
        RegExp(r'\bdsa\b').hasMatch(lower) ||
        lower.contains('data structure')) {
      return 'Data Structures';
    }

    if (RegExp(r'\boop\b').hasMatch(lower) ||
        lower.contains('object oriented')) {
      return 'OOP';
    }

    if (lower.contains('database') || RegExp(r'\bdb\b').hasMatch(lower)) {
      return 'Database';
    }

    if (lower.contains('operating system') || RegExp(r'\bos\b').hasMatch(lower)) {
      return 'Operating Systems';
    }

    if (lower.contains('linear algebra') || RegExp(r'\bla\b').hasMatch(lower)) {
      return 'Linear Algebra';
    }

    if (lower.contains('calculus ii') ||
        lower.contains('calculus 2') ||
        lower.contains('calc ii')) {
      return 'Calculus II';
    }

    if (lower.contains('calculus') || lower.contains('calc')) {
      return 'Calculus';
    }

    return null;
  }

  String? _instructionLanguageLabel(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('conducted in english') ||
        lower.contains('conduct in eng') ||
        lower.contains('taught in english') ||
        lower.contains('english instruction') ||
        lower.contains('in eng') ||
        lower.contains('in english') ||
        lower.contains('英文授課') ||
        lower.contains('英語授課')) {
      return 'English';
    }

    if (lower.contains('conducted in chinese') ||
        lower.contains('conduct in chinese') ||
        lower.contains('taught in chinese') ||
        lower.contains('chinese instruction') ||
        lower.contains('in chinese') ||
        lower.contains('中文授課') ||
        lower.contains('華語授課')) {
      return 'Chinese';
    }

    return null;
  }

  bool _asksForInstructionLanguage(String prompt) {
    final lower = prompt.toLowerCase();

    return lower.contains('conduct') ||
        lower.contains('taught in') ||
        lower.contains('instruction') ||
        lower.contains('in eng') ||
        lower.contains('in english') ||
        lower.contains('in chinese') ||
        lower.contains('授課');
  }

  bool _asksForLanguageSubject(String prompt) {
    final lower = prompt.toLowerCase();

    if (_asksForInstructionLanguage(prompt)) {
      return false;
    }

    return lower.contains('language course') ||
        lower.contains('english course') ||
        lower.contains('japanese course') ||
        lower.contains('chinese course') ||
        lower.contains('英文課') ||
        lower.contains('日文課') ||
        lower.contains('中文課');
  }

  bool _isSmallTalkOnly(String message) {
    final lower = message.toLowerCase().trim();

    final normalized = lower
        .replaceAll(RegExp(r'[-_.,!?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final hasCourseIntent =
        normalized.contains('course') ||
        normalized.contains('courses') ||
        normalized.contains('class') ||
        normalized.contains('classes') ||
        normalized.contains('credit') ||
        normalized.contains('credits') ||
        normalized.contains('schedule') ||
        normalized.contains('recommend') ||
        normalized.contains('recommendation') ||
        normalized.contains('find') ||
        normalized.contains('show me') ||
        normalized.contains('give me') ||
        normalized.contains('i need') ||
        normalized.contains('i want') ||
        normalized.contains('ge') ||
        normalized.contains('core') ||
        normalized.contains('elective') ||
        normalized.contains('language course') ||
        normalized.contains('lab') ||
        normalized.contains('pe') ||
        normalized.contains('cs') ||
        normalized.contains('i2p') ||
        normalized.contains('oop') ||
        normalized.contains('database') ||
        normalized.contains('calculus') ||
        normalized.contains('math') ||
        normalized.contains('physics') ||
        normalized.contains('chemistry') ||
        normalized.contains('prof') ||
        normalized.contains('professor') ||
        normalized.contains('teacher') ||
        normalized.contains('instructor') ||
        normalized.contains('taught by') ||
        normalized.contains('通識') ||
        normalized.contains('必修') ||
        normalized.contains('選修') ||
        normalized.contains('課') ||
        normalized.contains('學分') ||
        normalized.contains('教授') ||
        normalized.contains('老師');

    if (hasCourseIntent) {
      return false;
    }

    final greetingPattern = RegExp(
      r'^(hi|hello|hey|yo|halo|hallo|嗨|你好|哈囉)(\s+(bao\s*bao|baobao|bao bao|panda|熊貓))?$',
    );

    if (greetingPattern.hasMatch(normalized)) {
      return true;
    }

    final directBaoBaoGreeting =
        normalized == 'bao bao' ||
        normalized == 'baobao' ||
        normalized == 'hi baobao' ||
        normalized == 'hi bao bao' ||
        normalized == 'hello bao bao' ||
        normalized == 'hello baobao';

    if (directBaoBaoGreeting) {
      return true;
    }

    final asksIdentity =
        normalized.contains('who are you') ||
        normalized.contains('what are you') ||
        normalized.contains('what can you do') ||
        normalized.contains('help me') ||
        normalized.contains('how can you help') ||
        normalized.contains('你是誰') ||
        normalized.contains('你可以做什麼');

    if (asksIdentity) {
      return true;
    }

    final thanks =
        normalized == 'thanks' ||
        normalized == 'thank you' ||
        normalized == 'thank u' ||
        normalized == 'thx' ||
        normalized == '謝謝';

    if (thanks) {
      return true;
    }

    return false;
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
        'language': course.language,
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
    if (course.day == 0 || course.startSlot == 0) {
      return false;
    }

    for (final plannedCourse in widget.plannedCourses) {
      if (plannedCourse.id == course.id) continue;
      if (plannedCourse.day == 0 || plannedCourse.startSlot == 0) continue;
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

    final effectiveBottomInset = isSuccess ? 0.0 : bottomInset;
    
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isSuccess ? _continueWithResults : null,
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
                  math.max(24, effectiveBottomInset + 20),
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
                          stage: stage,
                        ),
                        const SizedBox(height: 6),
                        _BaoBaoAvatar(
                          floatController: _floatController,
                          pulseController: _pulseController,
                          sparkleController: _sparkleController,
                          stage: stage,
                        ),
                        const SizedBox(height: 24),
                        if (lastUserPrompt.isNotEmpty && !isSuccess) ...[
                          _UserPromptPreview(text: lastUserPrompt),
                          const SizedBox(height: 14),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          child: isLoading || isSuccess
                              ? _ThinkingStatus(stage: stage)
                              : Column(
                                  children: [
                                    _PromptInput(
                                      controller: _messageController,
                                      isDisabled: isLoading,
                                      onSend: () => sendPrompt(),
                                    ),
                                    const SizedBox(height: 14),
                                    _SuggestionChips(
                                      onSelected: sendPrompt,
                                    ),
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
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  final _BaoBaoStage stage;

  const _SpeechBubble({
    required this.text,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = stage == _BaoBaoStage.loading;
    final isSuccess = stage == _BaoBaoStage.success;
    final isError = stage == _BaoBaoStage.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSuccess
                    ? const Color(0xFFD8B4FE)
                    : isError
                        ? const Color(0xFFFFCDD7)
                        : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSuccess
                      ? const Color(0xFF7E3291).withValues(alpha: 0.17)
                      : Colors.black.withValues(alpha: 0.13),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
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
                  const SizedBox(width: 12),
                  const _LoadingDots(),
                ],
                if (isSuccess) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.touch_app_rounded,
                    color: Color(0xFF7E3291),
                    size: 21,
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

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 16,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final value = math.sin((controller.value * math.pi * 2) +
                  (index * math.pi / 3));
              final scale = 0.75 + ((value + 1) / 2) * 0.45;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7E3291),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
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
  final AnimationController sparkleController;
  final _BaoBaoStage stage;

  const _BaoBaoAvatar({
    required this.floatController,
    required this.pulseController,
    required this.sparkleController,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = stage == _BaoBaoStage.loading;
    final isSuccess = stage == _BaoBaoStage.success;
    final isError = stage == _BaoBaoStage.error;

    return AnimatedBuilder(
      animation: Listenable.merge([
        floatController,
        pulseController,
        sparkleController,
      ]),
      builder: (context, child) {
        final floatY = math.sin(floatController.value * math.pi * 2) * 5;
        final pulse = isLoading || isSuccess
            ? 1.0 + (pulseController.value * 0.09)
            : 1.0;
        final rotate = isLoading
            ? math.sin(floatController.value * math.pi * 2) * 0.035
            : 0.0;

        final glowColor = isSuccess
            ? const Color(0xFFFACC15)
            : isError
                ? const Color(0xFFFF2D55)
                : const Color(0xFF7E3291);

        final sparkleColor = isSuccess
            ? const Color(0xFFFACC15)
            : const Color(0xFF9333EA);

        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.rotate(
            angle: rotate,
            child: Transform.scale(
              scale: pulse,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSuccess ? 122 : 110,
                    height: isSuccess ? 122 : 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSuccess
                          ? const Color(0xFFFFF7CC)
                          : const Color(0xFFF3E8FF),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.32),
                          blurRadius: isSuccess ? 58 : 38,
                          spreadRadius: isSuccess ? 8 : 4,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: isSuccess ? 94 : 88,
                    height: isSuccess ? 94 : 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isSuccess
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFE9D5FF),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isSuccess
                            ? '🐼'
                            : isError
                                ? '🐼?'
                                : '🐼',
                        style: TextStyle(
                          fontSize: isSuccess ? 44 : 39,
                        ),
                      ),
                    ),
                  ),
                  if (isSuccess) ...[
                    Positioned(
                      top: -10,
                      right: -6,
                      child: _Sparkle(
                        size: 25,
                        delay: 0,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      left: -10,
                      child: _Sparkle(
                        size: 21,
                        delay: 0.35,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                    Positioned(
                      top: 28,
                      left: -22,
                      child: _Sparkle(
                        size: 16,
                        delay: 0.65,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: -24,
                      child: _Sparkle(
                        size: 17,
                        delay: 0.9,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      top: 4,
                      right: 2,
                      child: _Sparkle(
                        size: 18,
                        delay: 0,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                    Positioned(
                      top: 28,
                      right: -11,
                      child: _Sparkle(
                        size: 12,
                        delay: 0.3,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                    Positioned(
                      bottom: 9,
                      left: -6,
                      child: _Sparkle(
                        size: 13,
                        delay: 0.6,
                        controller: sparkleController,
                        color: sparkleColor,
                      ),
                    ),
                  ],
                ],
              ),
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
  final Color color;

  const _Sparkle({
    required this.size,
    required this.delay,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = ((controller.value + delay) % 1.0);
        final opacity = 0.35 + math.sin(value * math.pi) * 0.65;
        final scale = 0.75 + math.sin(value * math.pi) * 0.35;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: size,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _ThinkingStatus extends StatelessWidget {
  final _BaoBaoStage stage;

  const _ThinkingStatus({
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    if (stage == _BaoBaoStage.success) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E3291).withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF7E3291),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Tap anywhere to view the cards',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7E3291),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2.3,
              color: Color(0xFF7E3291),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Bao-Bao is thinking...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
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
        maxWidth: 340,
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
  final bool isDisabled;
  final VoidCallback onSend;

  const _PromptInput({
    required this.controller,
    required this.isDisabled,
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
              enabled: !isDisabled,
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
            onTap: isDisabled ? null : onSend,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDisabled
                    ? const Color(0xFFE9D5FF)
                    : const Color(0xFF7E3291),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDisabled
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