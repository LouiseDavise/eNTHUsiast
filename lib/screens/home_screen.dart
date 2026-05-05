import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

import '../../models/bulletin_model.dart';
import '../../models/task_model.dart';
import '../widgets/bulletin_board_widget.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/upcoming_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final List<Map<String, dynamic>> _bulletinMaps = [
    {
      'id': 'b1',
      'category': 'CAREER GROWTH',
      'title': 'Global Internship Program',
      'subtitle':
          'Apply before June 1st for summer placements at partner companies worldwide.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_11b93a64c-1771894463737.png',
      'semanticLabel':
          'Group of diverse professionals collaborating around a conference table in a modern office',
    },
    {
      'id': 'b2',
      'category': 'ACADEMIC',
      'title': 'Final Exam Schedule Released',
      'subtitle':
          'Check your personalized exam timetable for the 115 Spring Semester.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_18c124ef9-1767339932526.png',
      'semanticLabel':
          'Students studying at desks in a bright university library',
    },
    {
      'id': 'b3',
      'category': 'CAMPUS EVENT',
      'title': 'Innovation Hackathon 2026',
      'subtitle':
          'Form teams and register for the 48-hour campus design sprint.',
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_162b5396b-1771510329482.png',
      'semanticLabel':
          'Students presenting ideas at a hackathon event with laptops and whiteboards',
    },
  ];

  final List<Map<String, dynamic>> _taskMaps = [
    {
      'id': 't1',
      'courseCode': 'MATH201',
      'title': 'Mathematics Midterm',
      'status': 'critical',
      'deadline': '2026-05-19T09:00:00',
      'progressPercent': 0.0,
      'description': 'Chapters 1-6, closed book',
    },
    {
      'id': 't2',
      'courseCode': 'CS12345',
      'title': 'Software Studio Final',
      'status': 'critical',
      'deadline': '2026-05-26T23:59:00',
      'progressPercent': 0.0,
      'description': 'Full project submission',
    },
    {
      'id': 't3',
      'courseCode': 'MATH201',
      'title': 'Calculus Homework',
      'status': 'coursework',
      'deadline': '2026-05-19T23:59:00',
      'progressPercent': 0.5,
      'description': 'Problem sets 7-12',
    },
  ];

  late List<BulletinModel> _bulletins;
  late List<TaskModel> _tasks;

  @override
  void initState() {
    super.initState();
    _bulletins = _bulletinMaps.map(BulletinModel.fromMap).toList();
    _tasks = _taskMaps.map(TaskModel.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const _HomeAppBar(),
            Expanded(
              child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          BulletinBoardWidget(bulletins: _bulletins),
          const SizedBox(height: 20),
          const CalendarWidget(),
          const SizedBox(height: 20),
          UpcomingPreviewWidget(
            tasks: _tasks,
            onViewAll: () => {}
          ),
          const SizedBox(height: 80), // Keeps content from hiding behind the FAB
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  BulletinBoardWidget(bulletins: _bulletins),
                  const SizedBox(height: 20),
                  const CalendarWidget(), // Added const if possible
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: UpcomingPreviewWidget(
                tasks: _tasks,
                onViewAll: () => {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'eNTHUsiast',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '115 SPRING SEMESTER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08), // Replaced withOpacity for better standard compliance
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.question_mark_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}