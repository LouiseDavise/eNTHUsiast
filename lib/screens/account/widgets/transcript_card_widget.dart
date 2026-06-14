import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TranscriptCardWidget extends StatelessWidget {
  const TranscriptCardWidget({
    super.key,
    required this.record,
    this.isChinese = false,
  });
  final List<dynamic> record;
  final bool isChinese;

  // ── Peta nilai huruf ke poin GPA ─────────────────────────────────────────
  static const Map<String, double> _gpaMap = {
    'A+': 4.3,
    'A': 4.0,
    'A-': 3.7,
    'B+': 3.3,
    'B': 3.0,
    'B-': 2.7,
    'C+': 2.3,
    'C': 2.0,
    'C-': 1.7,
    '': 0.0,
  };

  // ── Warna badge berdasarkan grade ────────────────────────────────────────
  // Grade A → hijau, B → biru, C → amber, F → merah
  Color _gradeColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF059669);
    if (grade.startsWith('B')) return const Color(0xFF2563EB);
    if (grade.startsWith('C')) return const Color(0xFFD97706);
    return const Color(0xFFDC2626); // F atau kosong
  }

  Color _gradeBg(String grade) {
    if (grade.startsWith('A')) return const Color(0xFFD1FAE5);
    if (grade.startsWith('B')) return const Color(0xFFDBEAFE);
    if (grade.startsWith('C')) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  @override
  Widget build(BuildContext context) {
    // ── Kalkulasi GPA dan kredit semester ───────────────────────────────
    final year = record[0]['year'].substring(0, 3);
    final semesterCode = record[0]['year'][3];
    final semester = isChinese
        ? (semesterCode == '1' ? '上學期' : '下學期')
        : (semesterCode == '1' ? 'Fall' : 'Spring');

    var receivedCreds = 0;
    var totalCreds = 0;
    var value = 0.0;

    for (final course in record) {
      final cred = course['credits'] as int;
      totalCreds += cred;
      final grade = course['grade'].toString();
      if (grade.isEmpty) continue;
      // Akumulasi nilai × kredit untuk weighted GPA
      value += (_gpaMap[grade] ?? 0.0) * cred;
      receivedCreds += cred;
    }

    // Hindari division-by-zero jika totalCreds 0
    final gpa = totalCreds > 0
        ? ((value / totalCreds) * 100).round() / 100
        : 0.0;

    // ── Tentukan warna aksen berdasarkan GPA ────────────────────────────
    // GPA ≥ 3.7 → purple terang, 3.0–3.7 → biru, < 3.0 → slate
    final Color accentColor = gpa >= 3.7
        ? const Color(0xFF8A56AC)
        : gpa >= 3.0
            ? const Color(0xFF3B82F6)
            : const Color(0xFF64748B);

    return Container(
      // Lebar penuh mengikuti parent (SliverPadding 16px kanan-kiri)
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Strip aksen gradient di paling atas kartu ───────────────
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.4)],
                ),
              ),
            ),

            // ── Header: semester + GPA ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ikon kalender kecil sebagai aksen visual
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Label tahun dan semester
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isChinese
                              ? '$year 學年 $semester'
                              : '$year · $semester Semester',
                          style: GoogleFonts.dmSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isChinese
                              ? '已獲得 $receivedCreds 學分'
                              : '$receivedCreds credits earned',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Blok GPA di kanan atas
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'GPA',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 1.6,
                        ),
                      ),
                      Text(
                        gpa.toStringAsFixed(2),
                        style: GoogleFonts.dmSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Divider tipis sebelum daftar kursus ─────────────────────
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF1F5F9),
              indent: 20,
              endIndent: 20,
            ),

            // ── Daftar kursus ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  for (int i = 0; i < record.length; i++) ...[
                    _buildCourseRow(
                      record[i]['title'].toString(),
                      record[i]['credits'].toString(),
                      record[i]['grade'].toString(),
                    ),
                    // Tambahkan divider tipis di antara baris kursus (bukan setelah yang terakhir)
                    if (i < record.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF8FAFC),
                      ),
                  ],
                ],
              ),
            ),

            // ── Footer: label resmi ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 14,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isChinese ? '官方學業成績紀錄' : 'OFFICIAL ACADEMIC RECORD',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Satu baris kursus: judul, kredit, badge grade ────────────────────────
  Widget _buildCourseRow(String title, String credits, String grade) {
    final displayGrade = grade.isEmpty ? 'F' : grade;
    final badgeColor = _gradeColor(grade);
    final badgeBg = _gradeBg(grade);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nama dan kredit kursus di sisi kiri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isChinese ? '$credits 學分' : '$credits cr',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Badge grade berwarna di sisi kanan
          Container(
            width: 44,
            height: 32,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                displayGrade,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}