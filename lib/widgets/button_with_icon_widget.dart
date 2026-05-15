import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ButtonWithIconWidget extends StatefulWidget {
  final String btnName;
  final Icon btnIcon;
  final Color btnIconBgColor;
  final Function onTapFunc;

  const ButtonWithIconWidget({
    super.key,
    required this.btnName,
    required this.btnIcon,
    required this.btnIconBgColor,
    required this.onTapFunc,
  });

  @override
  State<ButtonWithIconWidget> createState() => _ButtonWithIconWidgetState();
}

class _ButtonWithIconWidgetState extends State<ButtonWithIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTapFunc();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.btnIconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.btnIcon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.btnName,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
