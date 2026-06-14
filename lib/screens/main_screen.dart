import 'package:flutter/material.dart';

import '../providers/language_provider.dart';
import 'account/account_screen.dart';
import 'courses/courses_screen.dart';
import 'home/home_screen.dart';
import 'social/social_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    SocialScreen(),
    CoursesScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.isChinese(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          // Page content fills the full screen
          Positioned.fill(
            child: _pages[_currentIndex],
          ),

          // Floating nav overlapping the bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_rounded,
                      label: isChinese ? '首頁' : 'Home',
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.explore_rounded,
                      label: isChinese ? '社群' : 'Social',
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.menu_book_rounded,
                      label: isChinese ? '課程' : 'Courses',
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.person_rounded,
                      label: isChinese ? '我的' : 'Account',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = _currentIndex == index;

    const Color primaryColor = Color(0xFF7A3392);
    const Color inactiveColor = Color(0xFFB0B3C7);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? primaryColor : inactiveColor,
                size: 24,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}