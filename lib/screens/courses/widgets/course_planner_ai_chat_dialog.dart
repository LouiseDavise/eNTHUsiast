import 'package:flutter/material.dart';

import 'bao_bao_avatar.dart';
import 'package:enthusiast/screens/courses/api/bao_bao_ai_api.dart';

class CoursePlannerAiChatDialog extends StatefulWidget {
  const CoursePlannerAiChatDialog({super.key});

  @override
  State<CoursePlannerAiChatDialog> createState() =>
      _CoursePlannerAiChatDialogState();
}

class _CoursePlannerAiChatDialogState extends State<CoursePlannerAiChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final BaoBaoAiApi _baoBaoAiApi = BaoBaoAiApi();

  bool isLoading = false;

  bool _isRecommendationRequest(String message) {
    final lower = message.toLowerCase();

    return lower.contains('recommend') ||
        lower.contains('suggest') ||
        lower.contains('what course') ||
        lower.contains('choose course') ||
        lower.contains('help me plan') ||
        lower.contains('course plan');
  }

  List<String> _recommendedCourseIds() {
    return [
      'cs210',
      'math202',
      'ge101',
      'pe101',
    ];
  }

  final List<_ChatMessage> messages = [
    _ChatMessage(
      text:
          'Hi, I’m Bao-Bao 🐼\nI can help you plan courses, check conflicts, and suggest a balanced schedule.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

 Future<void> sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || isLoading) {
      return;
    }

    setState(() {
      messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );
    });

    _messageController.clear();
    _scrollToBottom();

    if (_isRecommendationRequest(text)) {
      setState(() {
        messages.add(
          const _ChatMessage(
            text:
                'Bao-Bao found some recommended courses for you 🐼\nOpening Discover now...',
            isUser: false,
          ),
        );
      });

      _scrollToBottom();

      await Future.delayed(const Duration(milliseconds: 750));

      if (!mounted) return;

      Navigator.pop(context, _recommendedCourseIds());

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final reply = await _baoBaoAiApi.askBaoBao(text);

      if (!mounted) return;

      setState(() {
        messages.add(
          _ChatMessage(
            text: reply.trim().isEmpty
                ? 'Bao-Bao did not get a clear reply. Can you ask again?'
                : reply,
            isUser: false,
          ),
        );

        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        messages.add(
          _ChatMessage(
            text: _fallbackBaoBaoReply(text),
            isUser: false,
          ),
        );

        isLoading = false;
      });
    }

    _scrollToBottom();
  }

  String _fallbackBaoBaoReply(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hi! I’m Bao-Bao 🐼 How can I help with your course plan?';
    }

    if (lower.contains('conflict')) {
      return 'Bao-Bao thinks you should avoid conflict courses. Please check the courses marked with × CONFLICT.';
    }

    if (lower.contains('recommend') || lower.contains('suggest')) {
      return 'Bao-Bao suggests choosing a balanced mix of CORE, ELECTIVE, and GE courses.';
    }

    if (lower.contains('credit')) {
      return 'You can check your total selected credits at the top-right of the Course Planner page.';
    }

    return 'Bao-Bao cannot connect to AI right now, but I can still help with simple course planning questions.';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          height: screenHeight * 0.72,
          constraints: const BoxConstraints(
            maxHeight: 560,
            minHeight: 460,
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 14),
              _buildInfoCard(),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: messages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isLoading && index == messages.length) {
                      return const _TypingBubble();
                    }

                    final message = messages[index];
                    return _ChatBubble(message: message);
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildInputBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const BaoBaoAvatar(
          size: 52,
          showSparkle: true,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Ask Bao-Bao',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Ask me about course conflicts, credit balance, or course recommendations.',
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildInputBox() {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E3291).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => sendMessage(),
              cursorColor: const Color(0xFF7E3291),
              decoration: const InputDecoration(
                hintText: 'Ask about your course plan...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLoading
                    ? const Color(0xFFE9D5FF)
                    : const Color(0xFF7E3291),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7E3291),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 240,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            color: Color(0xFF7E3291),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const BaoBaoAvatar(
            size: 32,
            showSparkle: false,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 230,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const BaoBaoAvatar(
            size: 32,
            showSparkle: false,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF7E3291),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Bao-Bao is thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({
    required this.text,
    required this.isUser,
  });
}