import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/courses_material_model.dart';

class MaterialWeekCard extends StatefulWidget {
  final MaterialItem material;

  const MaterialWeekCard({
    super.key,
    required this.material,
  });

  @override
  State<MaterialWeekCard> createState() => _MaterialWeekCardState();
}

class _MaterialWeekCardState extends State<MaterialWeekCard> {
  bool isHovered = false;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: material.url != null ? () => _launchUrl(material.url!) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHovered ? 0.12 : 0.055),
                blurRadius: isHovered ? 16 : 10,
                offset: Offset(0, isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  size: 21,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.week.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11, // Increased from 9
                        fontWeight: FontWeight.w700, // Reduced from w900
                        letterSpacing: 0.5, // Reduced from 1.2
                        color: Color(0xFF9333EA),
                      ),
                    ),
                    const SizedBox(
                        height:
                            6), // Increased from 4 for better visual separation
                    Text(
                      material.title,
                      style: const TextStyle(
                        fontSize: 15, // Increased from 14
                        fontWeight: FontWeight
                            .w600, // Reduced from w900 for cleaner reading
                        height: 1.2, // Increased from 1.15
                        color: Color(0xFF020617),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isHovered ? const Color(0xFF9333EA) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHovered
                        ? const Color(0xFF9333EA)
                        : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isHovered ? 0.15 : 0.04),
                      blurRadius: isHovered ? 12 : 6,
                      offset: Offset(0, isHovered ? 4 : 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: isHovered ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
