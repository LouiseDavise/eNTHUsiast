import 'package:flutter/material.dart';

import 'department_code_data.dart';

class CareerPathsData {
  static IconData iconForCareer(String title) {
    final normalizedTitle = title.toLowerCase();

    if (normalizedTitle.contains('software') ||
        normalizedTitle.contains('developer') ||
        normalizedTitle.contains('devops')) {
      return Icons.code_rounded;
    }
    if (normalizedTitle.contains('data') ||
        normalizedTitle.contains('quant') ||
        normalizedTitle.contains('actuary') ||
        normalizedTitle.contains('analyst')) {
      return Icons.query_stats_rounded;
    }
    if (normalizedTitle.contains('ai') ||
        normalizedTitle.contains('machine learning') ||
        normalizedTitle.contains('bioinformatics')) {
      return Icons.psychology_alt_rounded;
    }
    if (normalizedTitle.contains('hardware') ||
        normalizedTitle.contains('ic') ||
        normalizedTitle.contains('semiconductor') ||
        normalizedTitle.contains('embedded') ||
        normalizedTitle.contains('firmware') ||
        normalizedTitle.contains('rf') ||
        normalizedTitle.contains('signal')) {
      return Icons.memory_rounded;
    }
    if (normalizedTitle.contains('cyber')) {
      return Icons.shield_rounded;
    }
    if (normalizedTitle.contains('cloud')) {
      return Icons.cloud_queue_rounded;
    }
    if (normalizedTitle.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (normalizedTitle.contains('ui') ||
        normalizedTitle.contains('ux') ||
        normalizedTitle.contains('designer') ||
        normalizedTitle.contains('design')) {
      return Icons.draw_rounded;
    }
    if (normalizedTitle.contains('robot') ||
        normalizedTitle.contains('mechatronics') ||
        normalizedTitle.contains('automation')) {
      return Icons.precision_manufacturing_rounded;
    }
    if (normalizedTitle.contains('mechanical') ||
        normalizedTitle.contains('thermal') ||
        normalizedTitle.contains('vehicle') ||
        normalizedTitle.contains('cae')) {
      return Icons.settings_suggest_rounded;
    }
    if (normalizedTitle.contains('product')) {
      return Icons.rocket_launch_rounded;
    }
    if (normalizedTitle.contains('power') ||
        normalizedTitle.contains('energy')) {
      return Icons.bolt_rounded;
    }
    if (normalizedTitle.contains('manufacturing') ||
        normalizedTitle.contains('process') ||
        normalizedTitle.contains('quality') ||
        normalizedTitle.contains('materials')) {
      return Icons.factory_rounded;
    }
    if (normalizedTitle.contains('investment') ||
        normalizedTitle.contains('financial')) {
      return Icons.account_balance_rounded;
    }
    if (normalizedTitle.contains('consultant') ||
        normalizedTitle.contains('technical consultant') ||
        normalizedTitle.contains('esg')) {
      return Icons.handshake_rounded;
    }
    if (normalizedTitle.contains('marketing') ||
        normalizedTitle.contains('brand')) {
      return Icons.campaign_rounded;
    }
    if (normalizedTitle.contains('operations') ||
        normalizedTitle.contains('supply chain')) {
      return Icons.account_tree_rounded;
    }
    if (normalizedTitle.contains('hr')) {
      return Icons.groups_rounded;
    }
    if (normalizedTitle.contains('research') ||
        normalizedTitle.contains('scientist') ||
        normalizedTitle.contains('lab')) {
      return Icons.science_rounded;
    }
    if (normalizedTitle.contains('biotech') ||
        normalizedTitle.contains('biomedical') ||
        normalizedTitle.contains('medical') ||
        normalizedTitle.contains('clinical') ||
        normalizedTitle.contains('pharma') ||
        normalizedTitle.contains('healthcare') ||
        normalizedTitle.contains('regulatory')) {
      return Icons.biotech_rounded;
    }
    if (normalizedTitle.contains('teacher') ||
        normalizedTitle.contains('lecturer') ||
        normalizedTitle.contains('curriculum') ||
        normalizedTitle.contains('learning') ||
        normalizedTitle.contains('edtech') ||
        normalizedTitle.contains('education')) {
      return Icons.school_rounded;
    }
    if (normalizedTitle.contains('counselor')) {
      return Icons.volunteer_activism_rounded;
    }
    if (normalizedTitle.contains('sports')) {
      return Icons.fitness_center_rounded;
    }
    if (normalizedTitle.contains('content') ||
        normalizedTitle.contains('editor') ||
        normalizedTitle.contains('writer') ||
        normalizedTitle.contains('translator')) {
      return Icons.edit_note_rounded;
    }
    if (normalizedTitle.contains('cultural') ||
        normalizedTitle.contains('curator') ||
        normalizedTitle.contains('public affairs') ||
        normalizedTitle.contains('policy')) {
      return Icons.public_rounded;
    }
    if (normalizedTitle.contains('environmental') ||
        normalizedTitle.contains('sustainability')) {
      return Icons.eco_rounded;
    }
    if (normalizedTitle.contains('nuclear') ||
        normalizedTitle.contains('safety')) {
      return Icons.health_and_safety_rounded;
    }

    return Icons.work_rounded;
  }

  static List<Map<String, dynamic>> getCareersByDepartment(String department) {
    final normalizedDepartment = _normalize(department);
    final matchedCodes = _matchedDepartmentCodes(normalizedDepartment);

    bool hasAny(List<String> keywords) {
      return keywords.any(
        (keyword) => normalizedDepartment.contains(_normalize(keyword)),
      );
    }

    bool hasCode(List<String> codes) {
      return codes.any((code) => matchedCodes.contains(code.toUpperCase()));
    }

    if (hasCode(['CS', 'IIS', 'ISA']) ||
        hasAny(['資工', '資訊工程', '資訊安全', '資安', '資料科學', 'cs'])) {
      return [
        {'title': 'Software Engineer', 'color': Colors.blue},
        {'title': 'Data Scientist', 'color': Colors.teal},
        {'title': 'AI/ML Engineer', 'color': Colors.deepPurple},
        {'title': 'Hardware Designer', 'color': Colors.blueGrey},
        {'title': 'Cybersec Analyst', 'color': Colors.redAccent},
        {'title': 'Cloud Architect', 'color': Colors.lightBlue},
        {'title': 'Game Developer', 'color': Colors.orange},
        {'title': 'DevOps Engineer', 'color': Colors.indigo},
        {'title': 'UI/UX Designer', 'color': Colors.pinkAccent},
      ];
    }

    if (hasCode([
          'EE',
          'EECS',
          'ENE',
          'COM',
          'IPT',
          'ISIC',
          'RDDM',
          'RDIC',
          'RDPE',
        ]) ||
        hasAny(['電機', '電子', '電資', '半導體', '光電', '通訊', 'ic設計'])) {
      return [
        {'title': 'IC Designer', 'color': Colors.indigo},
        {'title': 'Semiconductor Eng.', 'color': Colors.deepPurple},
        {'title': 'Firmware Engineer', 'color': Colors.teal},
        {'title': 'Signal Processing Eng.', 'color': Colors.blue},
        {'title': 'Power Engineer', 'color': Colors.amber},
        {'title': 'RF Engineer', 'color': Colors.redAccent},
        {'title': 'Embedded Engineer', 'color': Colors.green},
        {'title': 'Hardware Designer', 'color': Colors.blueGrey},
        {'title': 'Product Engineer', 'color': Colors.orange},
      ];
    }

    if (hasCode(['PME', 'IIMT']) || hasAny(['動機', '動力機械', '機械', '智造'])) {
      return [
        {'title': 'Mechanical Engineer', 'color': Colors.blue},
        {'title': 'Robotics Engineer', 'color': Colors.orange},
        {'title': 'Mechatronics Eng.', 'color': Colors.redAccent},
        {'title': 'Automation Eng.', 'color': Colors.deepPurple},
        {'title': 'Manufacturing Eng.', 'color': Colors.green},
        {'title': 'Thermal Engineer', 'color': Colors.amber},
        {'title': 'Vehicle Systems Eng.', 'color': Colors.indigo},
        {'title': 'Product Engineer', 'color': Colors.teal},
        {'title': 'CAE Engineer', 'color': Colors.blueGrey},
      ];
    }

    if (hasCode([
          'QF',
          'ECON',
          'TM',
          'IPMT',
          'MBA',
          'MFB',
          'IMBA',
          'ISS',
          'LST',
        ]) ||
        hasAny(['計財', '計量財務', '科管', '科技管理', '經濟', '財金', '經管', '服科', '科法'])) {
      return [
        {'title': 'Product Manager', 'color': Colors.deepPurple},
        {'title': 'Investment Banker', 'color': Colors.green},
        {'title': 'Consultant', 'color': Colors.blue},
        {'title': 'Financial Analyst', 'color': Colors.teal},
        {'title': 'Marketing Manager', 'color': Colors.orange},
        {'title': 'Operations Mgr.', 'color': Colors.blueGrey},
        {'title': 'Supply Chain Mgr.', 'color': Colors.amber},
        {'title': 'HR Partner', 'color': Colors.pinkAccent},
        {'title': 'Data Analyst', 'color': Colors.indigo},
      ];
    }

    if (hasCode(['CHE', 'MS', 'IEEM', 'BME', 'NEMS', 'IOSE']) ||
        hasAny(['化工', '材料', '工工', '工業工程', '醫工', '奈微', '太空'])) {
      return [
        {'title': 'Process Engineer', 'color': Colors.blue},
        {'title': 'Materials Engineer', 'color': Colors.deepPurple},
        {'title': 'Quality Engineer', 'color': Colors.green},
        {'title': 'Manufacturing Eng.', 'color': Colors.orange},
        {'title': 'Supply Chain Eng.', 'color': Colors.amber},
        {'title': 'R&D Engineer', 'color': Colors.teal},
        {'title': 'Biomedical Engineer', 'color': Colors.pinkAccent},
        {'title': 'Sustainability Eng.', 'color': Colors.lightGreen},
        {'title': 'Data Analyst', 'color': Colors.indigo},
      ];
    }

    if (hasCode([
          'LS',
          'DMS',
          'LSBT',
          'LSMC',
          'LSMM',
          'LSSN',
          'MPMI',
          'PMED',
          'THSM',
        ]) ||
        hasAny(['生科', '生命科學', '生醫', '醫科', '分生', '分醫', '神經', '精準醫療'])) {
      return [
        {'title': 'Research Scientist', 'color': Colors.deepPurple},
        {'title': 'Biotech R&D', 'color': Colors.green},
        {'title': 'Clinical Researcher', 'color': Colors.teal},
        {'title': 'Bioinformatics Analyst', 'color': Colors.indigo},
        {'title': 'Medical Scientist', 'color': Colors.redAccent},
        {'title': 'Pharma Specialist', 'color': Colors.blue},
        {'title': 'Lab Manager', 'color': Colors.orange},
        {'title': 'Regulatory Affairs', 'color': Colors.blueGrey},
        {'title': 'Healthcare PM', 'color': Colors.pinkAccent},
      ];
    }

    if (hasCode(['MATH', 'PHYS', 'CHEM', 'STAT', 'ASTR', 'ICMS']) ||
        hasAny(['數學', '物理', '化學', '統計', '天文', '計模', '理學'])) {
      return [
        {'title': 'Data Scientist', 'color': Colors.teal},
        {'title': 'Research Scientist', 'color': Colors.deepPurple},
        {'title': 'Quant Analyst', 'color': Colors.green},
        {'title': 'Actuary', 'color': Colors.indigo},
        {'title': 'Lab Scientist', 'color': Colors.orange},
        {'title': 'Machine Learning Eng.', 'color': Colors.blue},
        {'title': 'Semiconductor Eng.', 'color': Colors.blueGrey},
        {'title': 'Teacher / Lecturer', 'color': Colors.amber},
        {'title': 'Technical Consultant', 'color': Colors.redAccent},
      ];
    }

    if (hasCode([
          'CL',
          'FL',
          'HIS',
          'PHIL',
          'HSS',
          'SOC',
          'LING',
          'JAD',
          'JMU',
        ]) ||
        hasAny([
          '中文',
          '外語',
          '歷史',
          '哲學',
          '人社',
          '社會',
          '語言',
          '藝術',
          '音樂',
          '藝設',
          '華文',
        ])) {
      return [
        {'title': 'Content Strategist', 'color': Colors.orange},
        {'title': 'UX Researcher', 'color': Colors.deepPurple},
        {'title': 'Editor / Writer', 'color': Colors.blue},
        {'title': 'Translator', 'color': Colors.teal},
        {'title': 'Cultural Researcher', 'color': Colors.indigo},
        {'title': 'Brand Strategist', 'color': Colors.pinkAccent},
        {'title': 'Curator', 'color': Colors.amber},
        {'title': 'Public Affairs', 'color': Colors.green},
        {'title': 'Education Designer', 'color': Colors.blueGrey},
      ];
    }

    if (hasCode([
          'KEC',
          'KEE',
          'KEL',
          'KPC',
          'KSPE',
          'KSS',
          'KLST',
          'TE',
          'TEE',
          'TEG',
        ]) ||
        hasAny(['教育', '幼教', '教科', '心諮', '特教', '運科', '學習科學', '師培'])) {
      return [
        {'title': 'Teacher', 'color': Colors.blue},
        {'title': 'Counselor', 'color': Colors.pinkAccent},
        {'title': 'Learning Designer', 'color': Colors.deepPurple},
        {'title': 'EdTech Specialist', 'color': Colors.teal},
        {'title': 'Curriculum Designer', 'color': Colors.orange},
        {'title': 'Special Educator', 'color': Colors.green},
        {'title': 'Sports Scientist', 'color': Colors.redAccent},
        {'title': 'Research Assistant', 'color': Colors.indigo},
        {'title': 'Program Coordinator', 'color': Colors.blueGrey},
      ];
    }

    if (hasCode(['ESS', 'AES', 'NES', 'NUCL', 'ISDC', 'STMP', 'BMES']) ||
        hasAny(['工科', '原科', '核工', '環境', '永續', '氣候', '原子', '醫環'])) {
      return [
        {'title': 'Energy Engineer', 'color': Colors.amber},
        {'title': 'Environmental Eng.', 'color': Colors.green},
        {'title': 'Nuclear Engineer', 'color': Colors.deepPurple},
        {'title': 'Sustainability Analyst', 'color': Colors.teal},
        {'title': 'Safety Engineer', 'color': Colors.redAccent},
        {'title': 'ESG Consultant', 'color': Colors.blue},
        {'title': 'Research Scientist', 'color': Colors.indigo},
        {'title': 'Policy Analyst', 'color': Colors.blueGrey},
        {'title': 'Project Engineer', 'color': Colors.orange},
      ];
    }

    return [
      {'title': 'Project Manager', 'color': Colors.blue},
      {'title': 'Data Analyst', 'color': Colors.teal},
      {'title': 'Product Designer', 'color': Colors.pinkAccent},
      {'title': 'Software Developer', 'color': Colors.indigo},
      {'title': 'Operations Analyst', 'color': Colors.orange},
      {'title': 'Marketing Specialist', 'color': Colors.amber},
      {'title': 'Research Scientist', 'color': Colors.deepPurple},
      {'title': 'Consultant', 'color': Colors.blueGrey},
      {'title': 'Business Analyst', 'color': Colors.green},
    ];
  }

  static Set<String> _matchedDepartmentCodes(String normalizedDepartment) {
    final matches = <String>{};
    if (normalizedDepartment.isEmpty) return matches;

    for (final entry in departmentCodes.entries) {
      final code = entry.key.toUpperCase();
      final normalizedCode = _normalize(code);
      final normalizedName = _normalize(entry.value);

      if (normalizedDepartment.contains(normalizedCode) ||
          normalizedDepartment.contains(normalizedName) ||
          normalizedName.contains(normalizedDepartment)) {
        matches.add(code);
      }
    }

    return matches;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}
