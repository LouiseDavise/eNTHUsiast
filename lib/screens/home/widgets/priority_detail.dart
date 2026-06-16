import 'dart:ui';
import 'package:flutter/material.dart';

// --- Data model untuk satu suku dalam persamaan ---
//
// Format LLM aktual (baris ke-3):
//   "80(Tier 1) x 1.5(<48h) x 1.0(No fail) = 120"
//
// Setiap suku: <nilai>(<detail_tag>)
//   - value     → angka yang ditampilkan besar di tengah
//   - topLabel  → nama kategori tetap berdasarkan urutan: Base / Deadline / History
//   - detailTag → teks dalam kurung, ditampilkan sebagai chip kecil di BAWAH angka
class _EquationTerm {
  final String topLabel;   // Label kategori di ATAS angka (chip berwarna besar)
  final String detailTag;  // Detail spesifik di BAWAH angka (chip kecil abu)
  final double value;      // Nilai numerik (misal 80, 1.5, 1.0)
  final Color chipBackground;
  final Color chipText;
  final Color underlineColor;

  const _EquationTerm({
    required this.topLabel,
    required this.detailTag,
    required this.value,
    required this.chipBackground,
    required this.chipText,
    required this.underlineColor,
  });
}

// Label kategori tetap berdasarkan urutan suku
const List<String> _kTopLabels = ['Base', 'Deadline', 'History'];

// Palet warna pastel untuk setiap suku
const List<Map<String, Color>> _kTermPalettes = [
  {
    'bg':        Color(0xFFEEEDFE), // purple-50
    'text':      Color(0xFF3C3489), // purple-800
    'underline': Color(0xFF534AB7), // purple-600
  },
  {
    'bg':        Color(0xFFE1F5EE), // teal-50
    'text':      Color(0xFF085041), // teal-800
    'underline': Color(0xFF0F6E56), // teal-600
  },
  {
    'bg':        Color(0xFFFAECE7), // coral-50
    'text':      Color(0xFF712B13), // coral-800
    'underline': Color(0xFF993C1D), // coral-600
  },
  {
    'bg':        Color(0xFFFBEAF0), // pink-50
    'text':      Color(0xFF72243E), // pink-800
    'underline': Color(0xFF993556), // pink-600
  },
  {
    'bg':        Color(0xFFE6F1FB), // blue-50
    'text':      Color(0xFF0C447C), // blue-800
    'underline': Color(0xFF185FA5), // blue-600
  },
];

/// Mengurai baris ke-3 dari summary LLM.
///
/// Format aktual: "80(Tier 1) x 1.5(<48h) x 1.0(No fail) = 120"
/// Setiap suku cocok pola: <angka>(<teks_detail>)
/// Angka setelah "=" adalah skor total, diabaikan di sini.
List<_EquationTerm> _parseEquation(String equation) {
  final termPattern = RegExp(r'([\d]+(?:\.[\d]+)?)\(([^)]+)\)');
  final matches = termPattern.allMatches(equation).toList();

  final terms = <_EquationTerm>[];
  for (int i = 0; i < matches.length; i++) {
    final value     = double.tryParse(matches[i].group(1)!) ?? 0.0;
    final detailTag = matches[i].group(2)!.trim();
    final topLabel  = i < _kTopLabels.length ? _kTopLabels[i] : 'Factor ${i + 1}';

    final palette = _kTermPalettes[i % _kTermPalettes.length];
    terms.add(_EquationTerm(
      topLabel:       topLabel,
      detailTag:      detailTag,
      value:          value,
      chipBackground: palette['bg']!,
      chipText:       palette['text']!,
      underlineColor: palette['underline']!,
    ));
  }
  return terms;
}

/// Ambil skor total dari angka setelah "=" di baris ke-3.
/// Contoh: "80(Tier 1) x 1.5(<48h) x 1.0(No fail) = 120" → 120
double _parseTotalFromEquation(String equation) {
  final eqIndex = equation.lastIndexOf('=');
  if (eqIndex == -1) return 0.0;
  final afterEq = equation.substring(eqIndex + 1).trim();
  return double.tryParse(
    RegExp(r'[\d]+(?:\.[\d]+)?').firstMatch(afterEq)?.group(0) ?? '',
  ) ?? 0.0;
}

// ---------------------------------------------------------------------------

class PriorityDetailPopup extends StatelessWidget {
  final String summary;

  const PriorityDetailPopup({Key? key, required this.summary}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pisahkan baris, abaikan baris kosong
    final lines = summary.split('\n').where((l) => l.trim().isNotEmpty).toList();
    while (lines.length < 3) lines.add('');

    final scoreLine    = lines[0]; // "Priority Score = 100"
    final subtitleLine = lines[1]; // "Score = Base * Deadline * History"
    final equationLine = lines[2]; // "80(Tier 1) x 1.5(<48h) x 1.0(No fail) = 120"

    final terms      = equationLine.isNotEmpty ? _parseEquation(equationLine) : <_EquationTerm>[];
    final totalScore = equationLine.isNotEmpty ? _parseTotalFromEquation(equationLine) : 0.0;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),

              // Baris skor: "Priority Score = 100"
              Text(
                scoreLine.isNotEmpty ? scoreLine : 'Priority Score',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              // Subjudul: "Score = Base * Deadline * History"
              if (subtitleLine.isNotEmpty)
                Text(
                  subtitleLine,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                  ),
                ),
              const SizedBox(height: 20),

              // Blok persamaan berlabel
              if (terms.isNotEmpty)
                _buildEquationRow(terms, totalScore)
              else if (equationLine.isNotEmpty)
                _buildFallbackEquation(equationLine),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Header: ikon + "AI CALCULATION" + tombol tutup
  // --------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.calculate_rounded, size: 18, color: Colors.purple.shade400),
            const SizedBox(width: 6),
            Text(
              'AI CALCULATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.purple.shade400,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Baris persamaan horizontal dengan scroll
  // --------------------------------------------------------------------------
  Widget _buildEquationRow(List<_EquationTerm> terms, double totalScore) {
    final widgets = <Widget>[];

    for (int i = 0; i < terms.length; i++) {
      widgets.add(_buildTermColumn(terms[i]));
      if (i < terms.length - 1) widgets.add(_buildOperator('×'));
    }
    widgets.add(_buildOperator('='));
    widgets.add(_buildResultColumn(totalScore));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widgets,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Kolom satu suku:
  //   [chip topLabel berwarna]   ← ATAS
  //   [angka besar bergaris bawah]
  //   [chip detailTag abu kecil] ← BAWAH
  // --------------------------------------------------------------------------
  Widget _buildTermColumn(_EquationTerm term) {
    final valueText = term.value == term.value.truncateToDouble()
        ? term.value.toInt().toString()
        : term.value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ATAS: chip label kategori berwarna (Base / Deadline / History)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: term.chipBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              term.topLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: term.chipText,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // TENGAH: angka besar dengan garis bawah berwarna
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: term.underlineColor, width: 2.5),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              valueText,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // BAWAH: chip detail spesifik abu kecil (Tier 1, <48h, No fail, dll)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              term.detailTag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Operator "×" / "="
  // --------------------------------------------------------------------------
  Widget _buildOperator(String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w300,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Kolom hasil: angka total (capped) + chip "Score"
  // --------------------------------------------------------------------------
  Widget _buildResultColumn(double total) {
    final totalText = total == total.truncateToDouble()
        ? total.toInt().toString()
        : total.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spacer atas agar sejajar dengan chip topLabel
          const SizedBox(height: 29),
          const SizedBox(height: 6),
          Text(
            totalText,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFE8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Score',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444441),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Fallback: teks mentah jika parsing gagal
  // --------------------------------------------------------------------------
  Widget _buildFallbackEquation(String raw) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Text(
        raw,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          color: Colors.purple.shade700,
          height: 1.5,
        ),
      ),
    );
  }
}