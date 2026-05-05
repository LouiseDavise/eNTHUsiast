import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/bulletin_model.dart';
import '../../../widgets/custom_image_widget.dart';

class BulletinBoardWidget extends StatefulWidget {
  final List<BulletinModel> bulletins;

  const BulletinBoardWidget({super.key, required this.bulletins});

  @override
  State<BulletinBoardWidget> createState() => _BulletinBoardWidgetState();
}

class _BulletinBoardWidgetState extends State<BulletinBoardWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  // Auto-scroll colors for each bulletin card
  final List<List<Color>> _cardGradients = [
    [Color(0xFF0D9488), Color(0xFF0F766E)],
    [Color(0xFF6B21A8), Color(0xFF4C1D95)],
    [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.bulletins.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Bulletin Board',
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.expand_less_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.bulletins.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final bulletin = widget.bulletins[index];
                  final gradient =
                      _cardGradients[index % _cardGradients.length];
                  return _BulletinCard(
                    bulletin: bulletin,
                    gradientColors: gradient,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.bulletins.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppTheme.primary
                        : Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(100),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletinCard extends StatelessWidget {
  final BulletinModel bulletin;
  final List<Color> gradientColors;

  const _BulletinCard({required this.bulletin, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomImageWidget(
            imageUrl: bulletin.imageUrl,
            width: double.infinity,
            height: 160,
            fit: BoxFit.cover,
            semanticLabel: bulletin.semanticLabel,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors[0].withAlpha(224),
                  gradientColors[1].withAlpha(184),
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  bulletin.category,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withAlpha(217),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bulletin.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withAlpha(204),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'LEARN MORE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
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
