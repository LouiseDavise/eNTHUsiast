import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const Color _purple = Color(0xFF7B2F8E);
  static const Color _background = Color(0xFFF9F9F8);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _bodyText = Color(0xFF767993);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(),
                  const SizedBox(height: 34),
                  const Text(
                    'ABOUT US',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WHAT THIS APP IS FOR',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.045),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school_outlined, color: _purple, size: 36),
                        SizedBox(height: 18),
                        Text(
                          'eNTHUsiast',
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'eNTHUsiast is an all-in-one student productivity platform designed for NTHU students.',
                          style: TextStyle(
                            color: _bodyText,
                            fontSize: 15,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'The app helps students manage class schedules, upcoming tasks, school announcements, course materials, transcripts, graduation planning, and campus discussions in one place.',
                          style: TextStyle(
                            color: _bodyText,
                            fontSize: 15,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Our goal is to reduce the friction of using multiple school systems and give students a cleaner, faster, and more organized academic workflow.',
                          style: TextStyle(
                            color: _bodyText,
                            fontSize: 15,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pop(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: Color(0xFF9CA3AF), size: 20),
            SizedBox(width: 8),
            Text(
              'Back',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
