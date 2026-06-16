import 'package:flutter/material.dart';
import 'package:enthusiast/providers/language_provider.dart';

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

  // Display labels for the internal type sentinels. The underlying values
  // ('ALL', 'CORE', 'ELECTIVE', 'GE') stay unchanged since they're compared
  // elsewhere (e.g. _PinnedDiscoverSearchBar's hasFilter check) — only what
  // the user sees on the chip changes.
  String _typeLabel(String type, bool isChinese) {
    switch (type) {
      case 'ALL':
        return isChinese ? '全部' : 'All';
      case 'CORE':
        return isChinese ? '必修' : 'Core';
      case 'ELECTIVE':
        return isChinese ? '選修' : 'Elective';
      case 'GE':
        return isChinese ? '通識' : 'GE';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;

    // Guarantee an 'All' entry always exists in the dropdown's items list.
    // Previously, if widget.departmentOptions was non-empty but didn't
    // contain 'All', both initState's and this method's fallback to
    // selectedDepartment = 'All' pointed at a value with no matching
    // DropdownMenuItem, which throws a runtime assertion. Prepending it
    // here (and de-duping) makes 'All' always a valid, selectable value.
    final departments = <String>[
      'All',
      ...widget.departmentOptions.where((d) => d != 'All'),
    ];

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
                  Expanded(
                    child: Text(
                      isChinese ? '篩選課程' : 'Filter Courses',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: resetFilter,
                    child: Text(
                      isChinese ? '重設' : 'RESET',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7E3291),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(title: isChinese ? '課程類別' : 'COURSE TYPE'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: typeOptions.map((type) {
                  return _FilterChipButton(
                    label: _typeLabel(type, isChinese),
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
              _SectionLabel(title: isChinese ? '學分數' : 'CREDITS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: creditOptions.map((credit) {
                  final label =
                      credit == null ? (isChinese ? '全部' : 'All') : '$credit';

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
              _SectionLabel(title: isChinese ? '開課系所' : 'DEPARTMENT'),
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
                      final label = department == 'All'
                          ? (isChinese ? '全部系所' : 'All')
                          : department;

                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(
                          label,
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
                  child: Text(
                    isChinese ? '套用篩選' : 'APPLY FILTER',
                    style: const TextStyle(
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
            color: selected ? const Color(0xFF7E3291) : const Color(0xFFE5E7EB),
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
