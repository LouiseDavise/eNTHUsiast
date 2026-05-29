import 'dart:math' as math;

import 'package:flutter/material.dart';

class CoursePlannerAiButton extends StatefulWidget {
  final VoidCallback onTap;

  const CoursePlannerAiButton({
    super.key,
    required this.onTap,
  });

  @override
  State<CoursePlannerAiButton> createState() => _CoursePlannerAiButtonState();
}

class _CoursePlannerAiButtonState extends State<CoursePlannerAiButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _sparkleController;

  bool isPressed = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _sparkleController,
      ]),
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.045);
        final glowOpacity = 0.20 + (_pulseController.value * 0.12);
        final rotation = _sparkleController.value * 2 * math.pi;

        return GestureDetector(
          onTapDown: (_) {
            setState(() {
              isPressed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
          },
          onTapUp: (_) {
            setState(() {
              isPressed = false;
            });
            widget.onTap();
          },
          child: AnimatedScale(
            scale: isPressed ? 0.94 : pulse,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              height: 58,
              padding: const EdgeInsets.fromLTRB(16, 8, 18, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7E3291),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7E3291).withValues(
                      alpha: glowOpacity,
                    ),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: rotation,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Stack(
                            children: const [
                              Positioned(
                                top: 0,
                                right: 3,
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 9,
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                left: 0,
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}