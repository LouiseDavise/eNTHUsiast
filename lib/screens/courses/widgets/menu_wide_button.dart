import 'package:flutter/material.dart';

class MenuWideButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color activeColor;
  final Color inactiveBgColor;
  final Color inactiveIconColor;
  final VoidCallback onTap;

  const MenuWideButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeColor,
    required this.inactiveBgColor,
    required this.inactiveIconColor,
    required this.onTap,
  });

  @override
  State<MenuWideButton> createState() => _MenuWideButtonState();
}

class _MenuWideButtonState extends State<MenuWideButton> {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          transform: Matrix4.identity()
            ..translate(0.0, isPressed ? 2.0 : 0.0),
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
          child: Row(
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
                  size: 24,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 16, // Increased from 15
                        fontWeight: FontWeight.w600, // Reduced from w900
                        color: isActive
                            ? widget.activeColor
                            : const Color(0xFF111827),
                      ),
                      child: Text(widget.title),
                    ),

                    const SizedBox(height: 4), // Adjusted from 5 for tighter grouping

                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12, // Increased from 10
                        fontWeight: FontWeight.w600, // Reduced from w800
                        letterSpacing: 0.5, // Reduced from 1.0
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}