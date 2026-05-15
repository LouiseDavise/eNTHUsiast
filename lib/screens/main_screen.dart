import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'social_screen.dart';
import 'courses/courses_screen.dart';
import 'account_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // List of your empty pages
  final List<Widget> _pages = [
    const HomeScreen(),
    const SocialScreen(),
    const CoursesScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      // Bottom Navigation Bar
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
            _buildNavItem(0, Icons.home_outlined, "HOME"),
            _buildNavItem(1, Icons.near_me_outlined, "SOCIAL"),
            _buildNavItem(2, Icons.menu_book_outlined, "COURSES"),
            _buildNavItem(3, Icons.person_outline, "ACCOUNT"),
          ],
        ),
      ),
    );
  }

  // Individual nav Widget
  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    
    Color primaryColor = const Color(0xFF7A3392); // Deep Purple
    Color inactiveColor = const Color(0xFFB0B3C7); // Grey-blue

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
                      )
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
          // Label
          Text(
            label,
            style: TextStyle(
              color: isActive ? primaryColor : inactiveColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}