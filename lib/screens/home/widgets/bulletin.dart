import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Custom Data Model ────────────────────────────────────────────────────────
class DynamicBulletin {
  final String category;
  final String title;
  final String fullText;
  final List<Color> gradient;
  final IconData icon;

  DynamicBulletin({
    required this.category,
    required this.title,
    required this.fullText,
    required this.gradient,
    required this.icon,
  });
}

// ── Bulletin Widget ─────────────────────────────────────────────────────────
class BulletinWidget extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const BulletinWidget({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  State<BulletinWidget> createState() => _BulletinWidgetState();
}

class _BulletinWidgetState extends State<BulletinWidget> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  int _bulletinCount = 0;

  static const Color nthuPurple = Color(0xFF7E22CE);
  static const Color nthuPurpleLight = Color(0xFFF3E8FF);

  final Stream<QuerySnapshot<Map<String, dynamic>>> _bulletinsStream =
      FirebaseFirestore.instance
          .collection('bulletins')
          .orderBy('updatedAt', descending: true)
          .snapshots();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  List<DynamicBulletin> _parseBulletinDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final List<DynamicBulletin> results = [];

    for (final doc in docs) {
      final data = doc.data();

      final String fullText = (data['fullText'] ?? '').toString();
      final String snippet = (data['snippet'] ?? '').toString();
      final String titleFromFirebase =
          (data['title'] ?? 'Campus Announcements').toString();

      if (fullText.trim().isEmpty) {
        results.add(
          DynamicBulletin(
            category: 'ANNOUNCEMENT',
            title: titleFromFirebase,
            fullText: snippet.isNotEmpty
                ? snippet
                : 'No additional details provided.',
            gradient: const [
              Color(0xFF7E22CE),
              Color(0xFF3B82F6),
            ],
            icon: Icons.campaign_rounded,
          ),
        );
        continue;
      }

      // The NTHU bulletin email uses sections like:
      // * Administrative Announcements*
      // * Performance & Exhibition*
      // * Activities*
      final List<String> sections = fullText.split('* ');

      // Fallback if the email text does not follow the "* category*" format.
      if (sections.length <= 1) {
        results.add(
          DynamicBulletin(
            category: 'ANNOUNCEMENT',
            title: snippet.isNotEmpty ? snippet : titleFromFirebase,
            fullText: fullText,
            gradient: const [
              Color(0xFF7E22CE),
              Color(0xFF3B82F6),
            ],
            icon: Icons.campaign_rounded,
          ),
        );
        continue;
      }

      for (int i = 1; i < sections.length; i++) {
        final String chunk = sections[i];
        final int asteriskIdx = chunk.indexOf('*');

        if (asteriskIdx == -1) {
          continue;
        }

        final String category = chunk.substring(0, asteriskIdx).trim();
        final String rest = chunk.substring(asteriskIdx + 1).trim();

        final List<String> lines = rest
            .split('\n')
            .map((line) => line.trim())
            .where(
              (line) => line.isNotEmpty && !line.startsWith('<http'),
            )
            .toList();

        final String title =
            lines.isNotEmpty ? lines.first : 'Click to view details';

        final String cleanBody = rest
            .replaceAll(RegExp(r'<http[^>]+>'), '')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

        results.add(
          DynamicBulletin(
            category: category,
            title: title,
            fullText: cleanBody,
            gradient: _gradientForCategory(category),
            icon: _iconForCategory(category),
          ),
        );
      }
    }

    return results;
  }

  List<Color> _gradientForCategory(String category) {
    if (category.contains('Administrative')) {
      return const [
        Color(0xFF8B5CF6),
        Color(0xFF6D28D9),
      ];
    }

    if (category.contains('Lectures')) {
      return const [
        Color(0xFF3B82F6),
        Color(0xFF1D4ED8),
      ];
    }

    if (category.contains('Performance') || category.contains('Art')) {
      return const [
        Color(0xFFEC4899),
        Color(0xFFBE185D),
      ];
    }

    if (category.contains('Activities')) {
      return const [
        Color(0xFFF59E0B),
        Color(0xFFD97706),
      ];
    }

    if (category.contains('Learning')) {
      return const [
        Color(0xFF10B981),
        Color(0xFF047857),
      ];
    }

    if (category.contains('Others')) {
      return const [
        Color(0xFF64748B),
        Color(0xFF334155),
      ];
    }

    return const [
      Color(0xFF7E22CE),
      Color(0xFF4C1D95),
    ];
  }

  IconData _iconForCategory(String category) {
    if (category.contains('Administrative')) {
      return Icons.assignment_rounded;
    }

    if (category.contains('Lectures')) {
      return Icons.record_voice_over_rounded;
    }

    if (category.contains('Performance') || category.contains('Art')) {
      return Icons.palette_rounded;
    }

    if (category.contains('Activities')) {
      return Icons.event_rounded;
    }

    if (category.contains('Learning')) {
      return Icons.menu_book_rounded;
    }

    if (category.contains('Others')) {
      return Icons.info_outline_rounded;
    }

    return Icons.notifications_active_rounded;
  }

  void _updateBulletinCount(int count) {
    if (_bulletinCount == count) {
      return;
    }

    _bulletinCount = count;

    if (_currentIndex >= count && count > 0) {
      _currentIndex = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();

    if (!widget.isCollapsed && _bulletinCount > 1) {
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!_pageController.hasClients || _bulletinCount == 0) {
          return;
        }

        final int nextIndex = (_currentIndex + 1) % _bulletinCount;

        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void didUpdateWidget(BulletinWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _timer?.cancel();
      } else {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _showBulletinDetails(BuildContext context, DynamicBulletin item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  gradient: LinearGradient(
                    colors: item.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.category.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.title,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    item.fullText.isEmpty
                        ? 'No additional details provided.'
                        : item.fullText,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: const Color(0xFF374151),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required List<DynamicBulletin> items,
    required bool isLoading,
    String? errorMessage,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.only(
        top: 24,
        bottom: widget.isCollapsed ? 24 : 8,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(items.length),
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: widget.isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: nthuPurple,
                                ),
                              )
                            : errorMessage != null
                                ? Center(
                                    child: Text(
                                      errorMessage,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSans(
                                        color: const Color(0xFFEF4444),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : items.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No new announcements.',
                                          style: GoogleFonts.dmSans(),
                                        ),
                                      )
                                    : PageView.builder(
                                        controller: _pageController,
                                        scrollBehavior:
                                            ScrollConfiguration.of(context)
                                                .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.mouse,
                                            PointerDeviceKind.trackpad,
                                          },
                                        ),
                                        onPageChanged: (index) {
                                          setState(() {
                                            _currentIndex = index;
                                          });

                                          _startTimer();
                                        },
                                        itemCount: items.length,
                                        itemBuilder: (context, index) {
                                          final item = items[index];

                                          return GestureDetector(
                                            onTap: () {
                                              _showBulletinDetails(
                                                context,
                                                item,
                                              );
                                            },
                                            child: _BulletinPageCard(
                                              item: item,
                                            ),
                                          );
                                        },
                                      ),
                      ),
                      const SizedBox(height: 16),
                      if (!isLoading && errorMessage == null && items.isNotEmpty)
                        _buildDots(items.length),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: nthuPurpleLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: nthuPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulletin Board',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                if (widget.isCollapsed && itemCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: nthuPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$itemCount',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: widget.onToggleCollapse,
          icon: Icon(
            widget.isCollapsed
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildDots(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4,
          width: _currentIndex == index ? 16 : 4,
          decoration: BoxDecoration(
            color: _currentIndex == index
                ? nthuPurple
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bulletinsStream,
      builder: (context, snapshot) {
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        if (snapshot.hasError) {
          return _buildContent(
            items: const [],
            isLoading: false,
            errorMessage: 'Failed to load bulletins from Firebase.',
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final items = _parseBulletinDocs(docs);

        _updateBulletinCount(items.length);

        return _buildContent(
          items: items,
          isLoading: isLoading,
        );
      },
    );
  }
}

class _BulletinPageCard extends StatelessWidget {
  final DynamicBulletin item;

  const _BulletinPageCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: item.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              item.icon,
              size: 140,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                item.category.toUpperCase(),
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'LEARN MORE',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}