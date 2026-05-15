import 'package:flutter/material.dart';

import '../../../models/graduation_verification_model.dart';
import 'course_record_item.dart';

class GraduationCategoryCard extends StatefulWidget {
  final GraduationCategory category;

  const GraduationCategoryCard({
    super.key,
    required this.category,
  });

  @override
  State<GraduationCategoryCard> createState() => _GraduationCategoryCardState();
}

class _GraduationCategoryCardState extends State<GraduationCategoryCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 18, // Increased from 17
                          fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                          color: Color(0xFF020617),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${category.earnedCredits}',
                              style: const TextStyle(
                                fontSize: 22, // Increased from 20
                                fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                                color: Color(0xFF7E22CE),
                              ),
                            ),
                            TextSpan(
                              text: ' / ${category.requiredCredits} CREDITS',
                              style: const TextStyle(
                                fontSize: 12, // Increased from 9
                                fontWeight: FontWeight.w600, // Reduced from w900
                                letterSpacing: 0.5, // Reduced from 1
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? const Color(0xFF7E22CE)
                        : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded
                        ? Colors.white
                        : const Color(0xFF94A3B8),
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 14),
                const Text(
                  'COURSE RECORDS',
                  style: TextStyle(
                    fontSize: 11, // Increased from 9
                    fontWeight: FontWeight.w700, // Reduced from w900
                    letterSpacing: 1.0, // Reduced from 2.0
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 14),
                ...category.records.map(
                  (record) => CourseRecordItem(record: record),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}