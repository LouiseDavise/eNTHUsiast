import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import 'custom_image_widget.dart';
import 'package:enthusiast/providers/ccxp_data_provider.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({super.key});

  Map<String, String> _buildAcademicStats(Map<String, dynamic>? data) {
    if (data == null) {
      return {'gpa': '-', 'current': '-', 'total': '-'};
    }

    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final categories = data['categories'] as List<dynamic>? ?? [];

    final gpa = summary['cumulativeGpa']?.toString() ?? '0.00';
    int totalEarned = 0;
    int currentCredits = 0;

    for (final cat in categories) {
      totalEarned += (cat['earnedCredits'] ?? 0) as int;
      final records = cat['records'] as List<dynamic>? ?? [];
      for (final rec in records) {
        if (rec['status'] == 'inProgress') {
          currentCredits += (rec['credits'] ?? 0) as int;
        }
      }
    }

    return {
      'gpa': gpa,
      'current': currentCredits.toString(),
      'total': totalEarned.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final graduationData = context.watch<CcxpDataProvider>().graduationData;
    final academicStats = _buildAcademicStats(graduationData);

    return Column(
      children: [
        // ── 1. Banner & Overlapping Avatar ──────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // The Header Banner (Gradient)
            Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              // Optional: Add a subtle pattern or logo here if you have one
            ),

            // The Avatar
            Positioned(
              bottom: 0, // Pulls the avatar down to overlap the banner
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120, // Slightly larger
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ), // Crisp white border
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CustomImageWidget(
                        imageUrl:
                            'https://images.pexels.com/photos/8617741/pexels-photo-8617741.jpeg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        semanticLabel: 'Avatar of Nathan G.',
                      ),
                    ),
                  ),
                  // Online/Status Dot
                  Positioned(
                    bottom: 4,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Text(
          'Nathan',
          style: GoogleFonts.dmSans(
            fontSize: 26, // Slightly larger
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),

        // ID & Major Row with a "Chip" for visual interest
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '113006200',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF), // Very light purple
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'INTERACTION DESIGN',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7E22CE),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'nthu_student@nthu.edu.tw',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),

        const SizedBox(height: 32),

        // ── 3. Academic Stats Bar ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn(
                  'CUM. GPA',
                  academicStats['gpa']!,
                  const Color(0xFF7E22CE),
                ),
                const VerticalDivider(
                  color: Color(0xFFF3F4F6),
                  thickness: 2,
                  width: 32,
                ),
                _buildStatColumn(
                  'CURRENT CR.',
                  academicStats['current']!,
                  const Color(0xFF3B82F6),
                ),
                const VerticalDivider(
                  color: Color(0xFFF3F4F6),
                  thickness: 2,
                  width: 32,
                ),
                _buildStatColumn(
                  'TOTAL CR.',
                  academicStats['total']!,
                  const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Refined helper method for the stats
  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 24, // Made the numbers a bit bigger and bolder
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
