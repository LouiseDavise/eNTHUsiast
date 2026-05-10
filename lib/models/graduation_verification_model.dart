class GraduationCourseRecord {
  final String title;
  final int credits;
  final String grade;
  final bool passed;

  const GraduationCourseRecord({
    required this.title,
    required this.credits,
    required this.grade,
    required this.passed,
  });
}

class GraduationCategory {
  final String title;
  final int earnedCredits;
  final int requiredCredits;
  final List<GraduationCourseRecord> records;

  const GraduationCategory({
    required this.title,
    required this.earnedCredits,
    required this.requiredCredits,
    required this.records,
  });
}