import 'package:flutter/material.dart';

class ButtonSelectableWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const ButtonSelectableWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3EBF7) : Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8A56AC)
                : Colors.blueGrey.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? const Color(0xFF6B3A8F)
                    : const Color(0xFF1A233A),
              ),
            ),
            if (isSelected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B3A8F),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
