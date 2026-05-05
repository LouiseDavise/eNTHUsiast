import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'custom_image_widget.dart';

class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(38),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: CustomImageWidget(
                  imageUrl:
                      'https://images.pexels.com/photos/8617741/pexels-photo-8617741.jpeg',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  semanticLabel:
                      'Animated avatar of a student wearing headphones with a tired but friendly expression',
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Nathan G.',
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '113006200',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'INTERACTION DESIGN',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'nthu_student@nthu.edu.tw',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
