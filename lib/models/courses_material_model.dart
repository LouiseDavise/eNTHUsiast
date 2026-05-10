class CourseMaterial {
  final String id;
  final String title;
  final String code;
  final String platform;
  final String teacher;
  final String updatedText;
  final List<CourseUnit> units;

  const CourseMaterial({
    required this.id,
    required this.title,
    required this.code,
    required this.platform,
    required this.teacher,
    required this.updatedText,
    required this.units,
  });
}

class CourseUnit {
  final String title;
  final List<MaterialItem> materials;

  const CourseUnit({
    required this.title,
    required this.materials,
  });
}

class MaterialItem {
  final String week;
  final String title;

  const MaterialItem({
    required this.week,
    required this.title,
  });
}