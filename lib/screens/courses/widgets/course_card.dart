import 'package:flutter/material.dart';
import '../../../models/courses_model.dart';

/// A colored card that represents one course block in the timetable.
class CourseCard extends StatelessWidget {
  final CourseItem course;

  const CourseCard({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: course.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: course.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              course.title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: course.text,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            course.code,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: course.text.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
