import 'package:flutter/material.dart';

class MenuSquareButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color activeColor;
  final Color inactiveBgColor;
  final Color inactiveIconColor;
  final VoidCallback onTap;

  const MenuSquareButton({
    super.key,
    required this.title,
    required this.icon,
    required this.activeColor,
    required this.inactiveBgColor,
    required this.inactiveIconColor,
    required this.onTap,
  });

  @override
  State<MenuSquareButton> createState() => _MenuSquareButtonState();
}

class _MenuSquareButtonState extends State<MenuSquareButton> {
  bool isHovered = false;
  bool isPressed = false;

  bool get isActive => isHovered || isPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            isPressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            isPressed = false;
          });
          widget.onTap();
        },
        onTapCancel: () {
          setState(() {
            isPressed = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isActive
                  ? widget.activeColor.withOpacity(0.18)
                  : const Color(0xFFF3F4F6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.09 : 0.05),
                blurRadius: isActive ? 16 : 10,
                offset: Offset(0, isActive ? 6 : 3),
              ),
            ],
          ),
          transform: Matrix4.identity()
            ..translate(0.0, isPressed ? 2.0 : 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.activeColor
                      : widget.inactiveBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: isActive
                      ? Colors.white
                      : widget.inactiveIconColor,
                  size: 25,
                ),
              ),

              const SizedBox(height: 12),

              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, // Increased from 13
                  height: 1.2, // Increased from 1.1 for better line height if it wraps
                  fontWeight: FontWeight.w600, // Reduced from w900 for a cleaner UI
                  color: isActive
                      ? widget.activeColor
                      : const Color(0xFF111827),
                ),
                child: Text(widget.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
