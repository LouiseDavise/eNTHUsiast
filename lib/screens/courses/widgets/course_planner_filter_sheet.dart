import 'package:flutter/material.dart';

class PlannerFilterSheet extends StatefulWidget {
  final String initialType;
  final int? initialCredits;
  final String initialDepartment;

  const PlannerFilterSheet({
    super.key,
    required this.initialType,
    required this.initialCredits,
    required this.initialDepartment,
  });

  @override
  State<PlannerFilterSheet> createState() => _PlannerFilterSheetState();
}

class _PlannerFilterSheetState extends State<PlannerFilterSheet> {
  late String selectedType;
  late int? selectedCredits;
  late String selectedDepartment;

  final List<String> courseTypes = [
    'ALL',
    'CORE',
    'ELECTIVE',
    'LANGUAGE',
    'GE',
    'PE',
    'LAB',
  ];

  final List<int?> creditOptions = [
    null,
    1,
    2,
    3,
    4,
  ];

  final List<String> departments = [
    'All',
    'Computer Science',
    'Mathematics',
    'Physics',
    'Chemistry',
    'General Education',
    'Economics',
    'Psychology',
    'History',
    'Language',
    'Physical Education',
    'Sociology',
    'Arts',
    'Philosophy',
  ];

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    selectedCredits = widget.initialCredits;
    selectedDepartment = widget.initialDepartment;
  }

  void openDepartmentPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _DepartmentPickerSheet(
          departments: departments,
          selectedDepartment: selectedDepartment,
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedDepartment = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter Courses',
                    style: TextStyle(
                      fontSize: 22, // Increased from 18
                      fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const _SectionTitle('COURSE TYPE'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: courseTypes.map((type) {
                return _FilterChip(
                  label: type,
                  active: selectedType == type,
                  onTap: () {
                    setState(() {
                      selectedType = type;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            const _SectionTitle('CREDITS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: creditOptions.map((credit) {
                final label = credit == null ? 'All' : credit.toString();

                return _CircleFilter(
                  label: label,
                  active: selectedCredits == credit,
                  onTap: () {
                    setState(() {
                      selectedCredits = credit;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            const _SectionTitle('DEPARTMENT'),
            const SizedBox(height: 12),

            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: openDepartmentPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selectedDepartment == 'All'
                        ? Colors.transparent
                        : const Color(0xFFE9D5FF),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDepartment,
                        style: TextStyle(
                          fontSize: 14, // Increased from 13
                          fontWeight: FontWeight.w600, // Reduced from w800
                          color: selectedDepartment == 'All'
                              ? const Color(0xFF64748B)
                              : const Color(0xFF7E3291),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: selectedDepartment == 'All'
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF7E3291),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'type': selectedType,
                    'credits': selectedCredits,
                    'department': selectedDepartment,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E3291),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: const Color(0xFF7E3291).withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // Adjusted to 16 for standard sizing
                  ),
                ),
                child: const Text(
                  'APPLY',
                  style: TextStyle(
                    fontSize: 14, // Increased from 11
                    fontWeight: FontWeight.w700, // Reduced from w900
                    letterSpacing: 1.0, // Reduced from 1.6
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentPickerSheet extends StatelessWidget {
  final List<String> departments;
  final String selectedDepartment;

  const _DepartmentPickerSheet({
    required this.departments,
    required this.selectedDepartment,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),

          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Department',
                    style: TextStyle(
                      fontSize: 20, // Increased from 18
                      fontWeight: FontWeight.w800, // Reduced from w900, removed italic
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPadding),
              itemCount: departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final department = departments[index];
                final isSelected = department == selectedDepartment;

                return InkWell(
                  borderRadius: BorderRadius.circular(16), // Adjusted to 16
                  onTap: () {
                    Navigator.pop(context, department);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16, // Increased vertical padding slightly for better tap target
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF3E8FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD8B4FE)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            department,
                            style: TextStyle(
                              fontSize: 15, // Increased from 13
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500, // Reduced from w900/w700
                              color: isSelected
                                  ? const Color(0xFF7E3291)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7E3291),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12, // Increased from 10
        fontWeight: FontWeight.w700, // Reduced from w900
        letterSpacing: 1.0, // Reduced from 1.5
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), // Adjusted vertical padding
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7E3291) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF7E3291).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12, // Increased from 10
            fontWeight: FontWeight.w600, // Reduced from w900
            letterSpacing: 0.5, // Reduced from 1.0
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _CircleFilter extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CircleFilter({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7E3291) : const Color(0xFFF8FAFC),
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF7E3291).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15, // Increased from 13
              fontWeight: FontWeight.w700, // Reduced from w900
              color: active ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}