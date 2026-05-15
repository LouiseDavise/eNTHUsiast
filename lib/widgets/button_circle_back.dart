import 'package:flutter/material.dart';

class CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Color(0xFF94A3B8),
          size: 25,
        ),
      ),
    );
  }
}
