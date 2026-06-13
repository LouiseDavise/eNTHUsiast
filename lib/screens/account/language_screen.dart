import 'package:flutter/material.dart';

import '../../providers/language_provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const Color _purple = Color(0xFF7B2F8E);
  static const Color _purpleLight = Color(0xFFF3E9F7);
  static const Color _background = Color(0xFFF9F9F8);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _cardBorder = Color(0xFFE9E2EF);

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.watch(context);
    final isChinese = language.isChinese;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isChinese),
                const SizedBox(height: 48),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      children: [
                        _buildLanguageOption(
                          context: context,
                          label: isChinese ? '英文' : 'English',
                          language: AppLanguage.en,
                          isSelected: language.language == AppLanguage.en,
                        ),
                        const SizedBox(height: 16),
                        _buildLanguageOption(
                          context: context,
                          label: isChinese ? '繁體中文' : 'Traditional Chinese',
                          language: AppLanguage.zh,
                          isSelected: language.language == AppLanguage.zh,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isChinese) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: _textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isChinese ? '返回' : 'Back',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isChinese ? '語言設定' : 'LANGUAGE',
            style: TextStyle(
              color: _textDark,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: isChinese ? 1.0 : 0.4,
              fontStyle: isChinese ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isChinese ? '更改語言' : 'Change Language',
            style: const TextStyle(
              color: Color(0xFF8A8FA3),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String label,
    required AppLanguage language,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        LanguageScope.read(context).setLanguage(language);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? _purpleLight : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? _purple : _cardBorder,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.04 : 0.025),
              blurRadius: isSelected ? 16 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? _purple : _textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: language == AppLanguage.zh ? 0.6 : 0,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 9 : 0,
              height: isSelected ? 9 : 0,
              decoration: const BoxDecoration(
                color: _purple,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
