import 'package:flutter/material.dart';

class PlannerFilterSheet extends StatefulWidget {
  final String initialType;
  final int? initialCredits;
  final String initialDepartment;
  final List<String> departmentOptions;

  const PlannerFilterSheet({
    super.key,
    required this.initialType,
    required this.initialCredits,
    required this.initialDepartment,
    required this.departmentOptions,
  });

  @override
  State<PlannerFilterSheet> createState() => _PlannerFilterSheetState();
}

class _PlannerFilterSheetState extends State<PlannerFilterSheet> {
  late String selectedType;
  late int? selectedCredits;
  late String selectedDepartment;

  final List<String> typeOptions = const [
    'ALL',
    'CORE',
    'ELECTIVE',
    'GE',
  ];

  final List<int?> creditOptions = const [
    null,
    0,
    1,
    2,
    3,
    4,
  ];

  @override
  void initState() {
    super.initState();

    selectedType = widget.initialType;
    selectedCredits = widget.initialCredits;

    final departments = widget.departmentOptions;

    if (departments.contains(widget.initialDepartment)) {
      selectedDepartment = widget.initialDepartment;
    } else {
      selectedDepartment = 'All';
    }
  }

  void applyFilter() {
    Navigator.pop(context, {
      'type': selectedType,
      'credits': selectedCredits,
      'department': selectedDepartment,
    });
  }

  void resetFilter() {
    setState(() {
      selectedType = 'ALL';
      selectedCredits = null;
      selectedDepartment = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final departments = widget.departmentOptions.isEmpty
        ? ['All']
        : widget.departmentOptions;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Courses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: resetFilter,
                    child: const Text(
                      'RESET',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7E3291),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _SectionLabel(title: 'COURSE TYPE'),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: typeOptions.map((type) {
                  return _FilterChipButton(
                    label: type,
                    selected: selectedType == type,
                    onTap: () {
                      setState(() {
                        selectedType = type;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              _SectionLabel(title: 'CREDITS'),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: creditOptions.map((credit) {
                  final label = credit == null ? 'ALL' : '$credit';

                  return _FilterChipButton(
                    label: label,
                    selected: selectedCredits == credit,
                    onTap: () {
                      setState(() {
                        selectedCredits = credit;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              _SectionLabel(title: 'DEPARTMENT'),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: departments.contains(selectedDepartment)
                        ? selectedDepartment
                        : 'All',
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF7E3291),
                    ),
                    items: departments.map((department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(
                          department,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        selectedDepartment = value;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: applyFilter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E3291),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'APPLY FILTER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.tune_rounded,
          size: 15,
          color: Color(0xFF7E3291),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7E3291) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF7E3291)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}