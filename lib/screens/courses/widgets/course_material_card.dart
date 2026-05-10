import 'package:flutter/material.dart';

import '../../../models/courses_material_model.dart';

class CourseMaterialCard extends StatefulWidget {
  final CourseMaterial course;
  final VoidCallback onTap;

  const CourseMaterialCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  State<CourseMaterialCard> createState() => _CourseMaterialCardState();
}

class _CourseMaterialCardState extends State<CourseMaterialCard> {
  bool isHovered = false;
  bool isPressed = false;

  bool get isActive => isHovered || isPressed;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isElearn = course.platform.toUpperCase() == 'ELEARN';

    final activeColor = isElearn
        ? const Color(0xFF9333EA)
        : const Color(0xFF2563EB);

    final inactiveIconBgColor = isElearn
        ? const Color(0xFFF3E8FF)
        : const Color(0xFFEFF6FF);

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
          padding: const EdgeInsets.all(22),
          transform: Matrix4.identity()
            ..translate(0.0, isPressed ? 2.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive
                  ? activeColor.withOpacity(0.20)
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActive ? 0.09 : 0.06),
                blurRadius: isActive ? 18 : 12,
                offset: Offset(0, isActive ? 7 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isActive
                                  ? activeColor
                                  : const Color(0xFF020617),
                            ),
                            child: Text(
                              course.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PlatformBadge(
                          label: course.platform,
                          color: isElearn
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF97316),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            course.teacher,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          course.updatedText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF9333EA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveIconBgColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isElearn
                      ? Icons.menu_book_rounded
                      : Icons.access_time_rounded,
                  color: isActive ? Colors.white : activeColor,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PlatformBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          color: color,
        ),
      ),
    );
  }
}