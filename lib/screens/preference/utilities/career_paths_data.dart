import 'package:flutter/material.dart';

class CareerPathsData {
  static List<Map<String, dynamic>> getCareersByDepartment(String department) {
    // 1. Computer Science / Information Engineering (資訊工程 / 資工)
    if (department.contains('資訊工程') || department.contains('資工') || department.toLowerCase().contains('cs')) {
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
    // 2. Electrical / Mechanical (電機 / 動機)
    else if (department.contains('電機') || department.contains('動力機械') || department.contains('動機')) {
      return [
        {'title': 'IC Designer', 'color': Colors.indigo},
        {'title': 'Robotics Engineer', 'color': Colors.orange},
        {'title': 'Firmware Engineer', 'color': Colors.teal},
        {'title': 'Systems Engineer', 'color': Colors.blue},
        {'title': 'Power Engineer', 'color': Colors.amber},
        {'title': 'Mechatronics Eng.', 'color': Colors.redAccent},
        {'title': 'Automation Eng.', 'color': Colors.deepPurple},
        {'title': 'Manufacturing Eng.', 'color': Colors.green},
        {'title': 'Hardware Designer', 'color': Colors.blueGrey},
      ];
    } 
    // 3. Business / Tech Management (計財 / 科管 / 經濟)
    else if (department.contains('計量財務') || department.contains('科技管理') || department.contains('經濟')) {
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

    // 4. Default Fallback 
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
}