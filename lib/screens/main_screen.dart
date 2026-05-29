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
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 100,
        padding: const EdgeInsets.only(bottom: 10, top: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              label: isChinese ? '首頁' : 'HOME',
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.near_me_outlined,
              label: isChinese ? '社群' : 'SOCIAL',
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.menu_book_outlined,
              label: isChinese ? '課程' : 'COURSES',
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.person_outline,
              label: isChinese ? '我的' : 'ACCOUNT',
            ),
          ],
        ),
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive ? primaryColor : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : inactiveColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? primaryColor : inactiveColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: LanguageScope.isChinese(context) ? 0.4 : 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
