import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/providers/language_provider.dart';
import 'package:enthusiast/screens/account/widgets/transcript_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key});

  List<List<dynamic>> _buildTranscript(List<dynamic> records) {
    final List<dynamic> sorted = List.from(records);
    // Urutkan berdasarkan tahun akademik secara ascending
    sorted.sort((a, b) => a['year'].toString().compareTo(b['year'].toString()));

    final List<List<dynamic>> res = [];
    int i = 0;
    while (i < sorted.length) {
      final curr = sorted[i]['year'].toString();
      List<dynamic> temp = [];
      // Kelompokkan semua record dengan tahun yang sama ke dalam satu list
      while (i < sorted.length && sorted[i]['year'].toString() == curr) {
        temp.add(sorted[i]);
        i++;
      }
      res.add(temp);
    }

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;
    final graduationData = context.watch<CcxpDataProvider>().graduationData;
    final records = graduationData!['allRecords'];
    final transcriptEntries = _buildTranscript(records);

    return Scaffold(
      // Latar belakang putih
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Custom SliverAppBar dengan gradient ──────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isChinese ? '成績單' : 'TRANSCRIPT',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF8A56AC),
                      letterSpacing: 2.4,
                    ),
                  ),
                  Text(
                    isChinese ? '學業成績紀錄' : 'Academic Records',
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Radial glow di pojok kanan atas sebagai aksen warna
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF8A56AC).withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Subjudul ringkasan jumlah semester ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                // Tampilkan total semester yang tersedia
                isChinese
                    ? '共 ${transcriptEntries.length} 個學期'
                    : '${transcriptEntries.length} semester${transcriptEntries.length == 1 ? '' : 's'} on record',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          // ── Daftar kartu transkrip ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TranscriptCardWidget(
                      record: transcriptEntries[index],
                      isChinese: isChinese,
                    ),
                  );
                },
                // Bug fix: pakai .length (bukan .length - 1) agar semester terakhir ikut tampil
                childCount: transcriptEntries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}