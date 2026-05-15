import 'dart:async';
import 'package:flutter/material.dart';
import '../utilities/data.dart';
import '../utilities/models.dart';

class BulletinWidget extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const BulletinWidget({
    Key? key,
    required this.isCollapsed,
    required this.onToggleCollapse,
  }) : super(key: key);

  @override
  State<BulletinWidget> createState() => _BulletinWidgetState();
}

class _BulletinWidgetState extends State<BulletinWidget> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.isCollapsed) {
      _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (_pageController.hasClients) {
          int nextIndex = (_currentIndex + 1) % bulletinItems.length;
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
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

  @override
  Widget build(BuildContext context) {
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
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
                    child: const Icon(Icons.notifications_active_rounded, color: nthuPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bulletin Board",
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w900,
                          color: Colors.black),
                      ),
                      if (widget.isCollapsed)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: nthuPurple,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${bulletinItems.length}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: widget.onToggleCollapse,
                icon: Icon(
                  widget.isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                  color: Colors.grey.shade400,
                ),
              )
            ],
          ),

          // Animated Expanded Content
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            child: widget.isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180, // aspect-[16/9] approximation
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                            _startTimer(); // Reset timer on manual swipe
                          },
                          itemCount: bulletinItems.length,
                          itemBuilder: (context, index) {
                            final item = bulletinItems[index];
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
                                  // Background Icon (Watermark)
                                  Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Icon(
                                      item.icon,
                                      size: 140,
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  // Content
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        item.category.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        ),
                                        child: const Text(
                                          "LEARN MORE",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Dot Indicators
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          bulletinItems.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            width: _currentIndex == index ? 16 : 4,
                            decoration: BoxDecoration(
                              color: _currentIndex == index ? nthuPurple : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
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