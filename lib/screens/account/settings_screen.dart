import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/language_provider.dart';

// about_us_screen.dart dan more_screen.dart tidak lagi diperlukan —
// semua kontennya digabung ke dalam satu halaman ini

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _purple = Color(0xFF7B2F8E);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _bodyText = Color(0xFF4B5563);
  static const Color _divider = Color(0xFFF1F5F9);

  static const List<Map<String, String>> _members = [
    {'name': 'Louise Davise', 'role': 'Project Lead'},
    {'name': 'Amartyanada Chang', 'role': 'Backend'},
    {'name': 'Wilbert Kenneth Chen', 'role': 'Frontend'},
    {'name': 'Nathan Christo', 'role': 'Frontend'},
    {'name': 'Nathanael Robbie', 'role': 'Design'},
  ];

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.watch(context);
    final isChinese = language.isChinese;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: CustomScrollView(
              slivers: [
                // ── Header bar dengan back button ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        _BackButton(isChinese: isChinese),
                      ],
                    ),
                  ),
                ),

                // ── Identity block: logo glyph + nama + versi ────────────
                // Ini adalah signature element — badge produk yang ringkas dan
                // terasa seperti sebuah label rilis, bukan sekadar judul halaman
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Glyph "e" sebagai logo mark
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16), // Keeps the image corners rounded
                            child: Image.asset(
                              'assets/app_icon.png', // Replace with your actual local path
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'eNTHUsiast',
                              style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                color: _textDark,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Label versi sebagai pill kecil
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isChinese ? '版本 1.0  ·  清華大學' : 'Version 1.0  ·  NTHU',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _purple,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Deskripsi singkat aplikasi ───────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Text(
                      isChinese
                          ? '專為清華大學學生打造的一站式高效學習平台 — 整合課表、成績單、畢業學分規劃及校園社群討論空間。'
                          : 'An all-in-one student productivity platform for NTHU — '
                            'schedules, transcripts, graduation planning, and campus '
                            'discussions in one place.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _bodyText,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                // ── Divider ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: Divider(color: _divider, thickness: 1.5, height: 1),
                  ),
                ),

                // ── Label seksi tim ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Text(
                      isChinese ? '開發團隊' : 'DEVELOPED BY',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _textMuted,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ),

                // ── Daftar anggota tim ───────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final member = _members[index];
                        final name = member['name']!;
                        final role = member['role']!;
                        final isLast = index == _members.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              child: Row(
                                children: [
                                  // Avatar inisial
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _purple.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _initials(name),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: _purple,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Nama dan peran anggota
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: _textDark,
                                          ),
                                        ),
                                        Text(
                                          role,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Divider tipis di antara anggota (tidak setelah yang terakhir)
                            if (!isLast)
                              Divider(
                                color: _divider,
                                thickness: 1,
                                height: 1,
                              ),
                          ],
                        );
                      },
                      childCount: _members.length,
                    ),
                  ),
                ),

                // ── Footer: tagline kampus ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
                    child: Text(
                      isChinese ? '台灣清華大學精心製造。' : 'Made with care at NTHU, Taiwan.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD1D5DB),
                      ),
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

  // Ambil inisial dari nama lengkap (huruf pertama + huruf terakhir kata)
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Tombol back dengan style konsisten ──────────────────────────────────────
class _BackButton extends StatelessWidget {
  final bool isChinese;

  const _BackButton({required this.isChinese});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pop(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF9CA3AF), size: 20),
            const SizedBox(width: 8),
            Text(
              isChinese ? '返回' : 'Back',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF9CA3AF),
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