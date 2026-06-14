import 'package:flutter/material.dart';

import '../../providers/language_provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const Color _purple = Color(0xFF7B2F8E);
  static const Color _purpleLight = Color(0xFFF3E9F7);
  static const Color _purpleMid = Color(0xFFA86CBE);
  static const Color _purpleBorder = Color(0xFFE5D4EE);
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
                const SizedBox(height: 24),
                _buildSectionLabel(isChinese),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildLanguageOption(
                        context: context,
                        flag: '🇺🇸',
                        label: isChinese ? '英文' : 'English',
                        nativeLabel: 'English',
                        language: AppLanguage.en,
                        currentLanguage: language.language,
                      ),
                      const SizedBox(height: 12),
                      _buildLanguageOption(
                        context: context,
                        flag: '🇹🇼',
                        label: isChinese ? '繁體中文' : 'Traditional Chinese',
                        nativeLabel: '繁體中文',
                        language: AppLanguage.zh,
                        currentLanguage: language.language,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoFooter(isChinese),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isChinese) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left_rounded,
                      size: 22, color: _textMuted),
                  const SizedBox(width: 2),
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
          const SizedBox(height: 18),
          // Eyebrow
          Text(
            isChinese ? '設定' : 'SETTINGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _purple,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          // Title
          Text(
            isChinese ? '語言設定' : 'Language',
            style: const TextStyle(
              color: _textDark,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            isChinese ? '更改顯示語言' : 'Change your display language',
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Divider
          const Divider(color: _cardBorder, thickness: 1, height: 1),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(bool isChinese) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        isChinese ? '選擇語言' : 'SELECT A LANGUAGE',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String flag,
    required String label,
    required String nativeLabel,
    required AppLanguage language,
    required AppLanguage currentLanguage,
  }) {
    final isSelected = currentLanguage == language;

    return GestureDetector(
      onTap: () => LanguageScope.read(context).setLanguage(language),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _purpleLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _purple : _cardBorder,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.04 : 0.025),
              blurRadius: isSelected ? 16 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Flag tile
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : _purpleLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _purpleBorder),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            // Language name + native label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? _purple : _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nativeLabel,
                    style: TextStyle(
                      color: isSelected ? _purpleMid : _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Active badge
            if (isSelected) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Radio checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _purple : Colors.transparent,
                border: isSelected
                    ? null
                    : Border.all(color: _cardBorder, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoFooter(bool isChinese) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon tile
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _purpleLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 16, color: _purple),
            ),
            const SizedBox(width: 12),
            // Note text
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textMuted,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: isChinese ? '立即生效。' : 'Changes apply instantly. ',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: isChinese
                          ? '所有畫面將立即切換至所選語言，無需重新啟動應用程式。'
                          : 'All screens update to the selected language without restarting the app.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}