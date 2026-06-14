import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Adjust this import path to match your folder structure
import 'package:enthusiast/providers/ccxp_data_provider.dart';
import '../main_screen.dart';
import 'utilities/career_paths_data.dart';

// Global variable that resets to false on every Hot Restart
bool hasShownPreferencesThisSession = false;

class PreferenceScreen extends StatefulWidget {
  final bool returnToPrevious;

  const PreferenceScreen({super.key, this.returnToPrevious = false});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  static const Color nthuPurple = Color(0xFF7A3392);

  int _currentStep = 0;
  final int _totalSteps = 7; // 6 Questions + 1 Final Page

  // Q1 State
  RangeValues _timeIndexRange = const RangeValues(0, 25);
  final List<int> _classTimeCheckpoints = [
    480,
    530,
    540,
    590,
    610,
    660,
    670,
    720,
    730,
    780,
    800,
    850,
    860,
    910,
    930,
    980,
    990,
    1040,
    1050,
    1100,
    1110,
    1160,
    1170,
    1220,
    1230,
    1280,
  ];

  // Q2 State
  int _selectedCreditIndex = 1;
  final List<String> _creditOptions = ['< 16', '16 - 18', '19 - 21', '22 - 25'];

  // Q3 State
  double _coreCourses = 4;

  // Q4 State (Career Paths)
  final List<String> _selectedCareers = [];

  // Q5 State (GE Course Interests)
  final List<String> _selectedGECategories = [];

  // Q6 State (Language Preference)
  int _selectedLanguageIndex = -1; // 0 for English, 1 for Chinese
  bool _isSavingPreferences = false;

  @override
  void initState() {
    super.initState();
    hasShownPreferencesThisSession = true;
    _loadSavedPreferences();
  }

  String _formatTime(double totalMinutes) {
    int h = (totalMinutes ~/ 60).toInt();
    int m = (totalMinutes % 60).toInt();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _nearestTimeIndex(int minutes) {
    var bestIndex = 0;
    var bestDistance = (minutes - _classTimeCheckpoints.first).abs();

    for (var i = 1; i < _classTimeCheckpoints.length; i++) {
      final distance = (minutes - _classTimeCheckpoints[i]).abs();
      if (distance < bestDistance) {
        bestIndex = i;
        bestDistance = distance;
      }
    }

    return bestIndex;
  }

  Future<void> _loadSavedPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(uid)
          .get();
      final preferences = snapshot.data()?['preferences'];
      if (preferences is! Map<String, dynamic> || !mounted) return;

      final timeWindow = preferences['timeWindow'];
      final selectedCareers = preferences['careerPaths'];
      final selectedGECategories = preferences['geInterests'];
      final languagePreference = preferences['languagePreference'];

      setState(() {
        if (timeWindow is Map) {
          final start = timeWindow['startMinutes'];
          final end = timeWindow['endMinutes'];
          if (start is num && end is num) {
            final startIndex = _nearestTimeIndex(start.toInt());
            final endIndex = _nearestTimeIndex(end.toInt());
            _timeIndexRange = RangeValues(
              startIndex.toDouble(),
              endIndex.toDouble(),
            );
          }
        }

        final targetCreditLoad = preferences['targetCreditLoad'];
        final creditIndex = _creditOptions.indexOf(targetCreditLoad.toString());
        if (creditIndex != -1) {
          _selectedCreditIndex = creditIndex;
        }

        final coreCourses = preferences['coreCourses'];
        if (coreCourses is num) {
          _coreCourses = coreCourses.toDouble().clamp(0, 8).toDouble();
        }

        if (selectedCareers is List) {
          _selectedCareers
            ..clear()
            ..addAll(selectedCareers.map((item) => item.toString()));
        }

        if (selectedGECategories is List) {
          _selectedGECategories
            ..clear()
            ..addAll(selectedGECategories.map((item) => item.toString()));
        }

        if (languagePreference == 'English Taught') {
          _selectedLanguageIndex = 0;
        } else if (languagePreference == 'Chinese Taught') {
          _selectedLanguageIndex = 1;
        }
      });
    } catch (_) {
      // Preferences are optional; users can continue and overwrite them.
    }
  }

  Future<void> _savePreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No signed-in user found.');
    }

    final startMins = _classTimeCheckpoints[_timeIndexRange.start.toInt()];
    final endMins = _classTimeCheckpoints[_timeIndexRange.end.toInt()];
    final languagePreference =
        _selectedLanguageIndex == 0 ? 'English Taught' : 'Chinese Taught';

    await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).set({
      'preferences': {
        'timeWindow': {
          'startMinutes': startMins,
          'endMinutes': endMins,
          'startLabel': _formatTime(startMins.toDouble()),
          'endLabel': _formatTime(endMins.toDouble()),
        },
        'targetCreditLoad': _creditOptions[_selectedCreditIndex],
        'coreCourses': _coreCourses.toInt(),
        'careerPaths': List<String>.from(_selectedCareers),
        'geInterests': List<String>.from(_selectedGECategories),
        'languagePreference': languagePreference,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      setState(() {
        _isSavingPreferences = true;
      });

      try {
        await _savePreferences();
        if (!mounted) return;
        if (widget.returnToPrevious && Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSavingPreferences = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e')),
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      // Mundur ke langkah sebelumnya jika bukan langkah pertama
      setState(() {
        _currentStep--;
      });
    } else if (widget.returnToPrevious && Navigator.canPop(context)) {
      // Jika di langkah pertama dan dibuka dari AccountScreen, kembali ke sana
      Navigator.pop(context);
    }
    // Jika returnToPrevious=false (dari GatekeeperScreen/main.dart),
    // tombol back di step 0 tidak melakukan apa-apa — user harus menyelesaikan wizard
  }

  // --- Helper: Dynamic Career Options (Q4) ---
  String _getStudentDepartment() {
    final provider = Provider.of<CcxpDataProvider>(context, listen: false);
    final graduationData = provider.graduationData;
    final studentInfo = graduationData?['studentInfo'];

    if (studentInfo is Map) {
      final department = studentInfo['studentDepartment'];
      if (department != null && department.toString().trim().isNotEmpty) {
        return department.toString().trim();
      }
    }

    final department = graduationData?['department'];
    if (department != null && department.toString().trim().isNotEmpty) {
      return department.toString().trim();
    }

    return '';
  }

  List<Map<String, dynamic>> _getDynamicCareers() {
    return CareerPathsData.getCareersByDepartment(_getStudentDepartment());
  }

  // --- Helper: GE Course Categories (Q5) ---
  final List<Map<String, dynamic>> _geCategories = [
    {
      'title': 'Humanities\n& Lit.',
      'icon': Icons.menu_book_rounded,
      'color': Colors.orange,
    },
    {
      'title': 'Social\nSciences',
      'icon': Icons.groups_rounded,
      'color': Colors.blue,
    },
    {
      'title': 'Arts &\nAesthetics',
      'icon': Icons.palette_rounded,
      'color': Colors.pink,
    },
    {
      'title': 'Natural\nSciences',
      'icon': Icons.science_rounded,
      'color': Colors.green,
    },
    {
      'title': 'Life Sci.\n& Health',
      'icon': Icons.psychology_rounded,
      'color': Colors.teal,
    },
    {
      'title': 'Global\nStudies',
      'icon': Icons.public_rounded,
      'color': Colors.indigo,
    },
    {
      'title': 'Tech &\nSociety',
      'icon': Icons.memory_rounded,
      'color': Colors.blueGrey,
    },
    {
      'title': 'Business\n& Economy',
      'icon': Icons.trending_up_rounded,
      'color': Colors.amber,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                const Color(0xFFF8FAFC),
                nthuPurple.withOpacity(0.04),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.04),
                          end: Offset.zero,
                        ).animate(curved),
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.985,
                            end: 1,
                          ).animate(curved),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey<int>(_currentStep),
                      alignment: Alignment.center,
                      child: _buildCurrentQuestion(),
                    ),
                  ),
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    // Hide the top bar entirely on the final confirmation page
    if (_currentStep == _totalSteps - 1) {
      return const SizedBox(height: 56);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _previousStep,
          ),
          const SizedBox(width: 8),
          // Segmented Progress Bar (Animated)
          Expanded(
            child: Row(
              children: List.generate(_totalSteps - 1, (index) {
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    height: 6,
                    decoration: BoxDecoration(
                      color: index <= _currentStep
                          ? nthuPurple
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildCurrentQuestion() {
    switch (_currentStep) {
      case 0:
        return _buildTimeQuestion();
      case 1:
        return _buildCreditsQuestion();
      case 2:
        return _buildCoreCoursesQuestion();
      case 3:
        return _buildCareerQuestion(); // Q4: Careers
      case 4:
        return _buildGEQuestion(); // Q5: Elective Fields
      case 5:
        return _buildLanguageQuestion(); // Q6: Language
      case 6:
        return _buildFinalPage(); // Final Page
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Question 1: Time Window ---
  Widget _buildTimeQuestion() {
    int startMins = _classTimeCheckpoints[_timeIndexRange.start.toInt()];
    int endMins = _classTimeCheckpoints[_timeIndexRange.end.toInt()];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "When do you prefer to have your classes?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 60),
        Text(
          "${_formatTime(startMins.toDouble())}  -  ${_formatTime(endMins.toDouble())}",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: nthuPurple,
          ),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: nthuPurple,
            inactiveTrackColor: nthuPurple.withOpacity(0.2),
            thumbColor: Colors.white,
            trackHeight: 12,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 4,
            ),
          ),
          child: RangeSlider(
            values: _timeIndexRange,
            min: 0,
            max: (_classTimeCheckpoints.length - 1).toDouble(),
            divisions: _classTimeCheckpoints.length - 1,
            onChanged: (RangeValues values) =>
                setState(() => _timeIndexRange = values),
          ),
        ),
      ],
    );
  }

  // --- Question 2: Credits ---
  Widget _buildCreditsQuestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "What is your target credit load?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 40),
        ...List.generate(_creditOptions.length, (index) {
          bool isSelected = _selectedCreditIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCreditIndex = index),
            child: AnimatedScale(
              scale: isSelected ? 0.98 : 1.0, // Slight dip when selected
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected ? nthuPurple.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? nthuPurple : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: nthuPurple.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _creditOptions[index],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? nthuPurple : Colors.black87,
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check, color: nthuPurple),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Question 3: Core Courses ---
  Widget _buildCoreCoursesQuestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "How many core courses are you taking?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 60),
        Text(
          "${_coreCourses.toInt()} Courses",
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: nthuPurple,
          ),
        ),
        const SizedBox(height: 32),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: nthuPurple,
            inactiveTrackColor: nthuPurple.withOpacity(0.2),
            thumbColor: Colors.white,
            trackHeight: 12,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14,
              elevation: 4,
            ),
          ),
          child: Slider(
            value: _coreCourses,
            min: 0,
            max: 8,
            divisions: 8,
            onChanged: (value) => setState(() => _coreCourses = value),
          ),
        ),
      ],
    );
  }

  // --- Question 4: Career Aims ---
  Widget _buildCareerQuestion() {
    final careerOptions = _getDynamicCareers();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Which career paths interest you the most?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Select up to 3",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: careerOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final option = careerOptions[index];
              final title = option['title'] as String;
              final color = option['color'] as Color;
              final icon = CareerPathsData.iconForCareer(title);
              final isSelected = _selectedCareers.contains(title);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCareers.remove(title);
                    } else if (_selectedCareers.length < 3) {
                      _selectedCareers.add(title);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You can only select up to 3 careers.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  });
                },
                child: AnimatedScale(
                  // Extra bouncy feel for the circles
                  scale: isSelected ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(isSelected ? 0.95 : 0.62),
                                  color,
                                ],
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.28),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: color.withOpacity(0.18),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 34),
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: AnimatedScale(
                                scale: isSelected ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.elasticOut,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: nthuPurple,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? nthuPurple : Colors.black87,
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
    );
  }

  // --- Question 5: GE Course Fields (2 Columns per row) ---
  Widget _buildGEQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Text(
          "What types of elective courses interest you?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Select all that apply",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _geCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              // Changed to 2 boxes per row
              crossAxisCount: 2,
              // Adjusted ratio so they look like nice rounded cards instead of stretched squares
              childAspectRatio: 1.25,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final category = _geCategories[index];
              final String title = category['title'].toString().replaceAll(
                    '\n',
                    ' ',
                  ); // Flatten text for wider cards
              final IconData icon = category['icon'];
              final Color iconColor = category['color'];
              final bool isSelected = _selectedGECategories.contains(title);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedGECategories.remove(title);
                    } else {
                      _selectedGECategories.add(title);
                    }
                  });
                },
                child: AnimatedScale(
                  // Bouncy squish effect on selection
                  scale: isSelected ? 0.93 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? nthuPurple.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? nthuPurple : Colors.grey.shade200,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 38, color: iconColor),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: Icon(
                              Icons.check_circle,
                              color: nthuPurple,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Question 6: Language Preference ---
  Widget _buildLanguageQuestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Preferred Language of Instruction?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            _buildLanguageCard(
              index: 0,
              title: "English Taught",
              symbol: "A",
              iconColor: Colors.blueAccent,
            ),
            const SizedBox(width: 16),
            _buildLanguageCard(
              index: 1,
              title: "Chinese Taught",
              symbol: "文",
              iconColor: Colors.redAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageCard({
    required int index,
    required String title,
    required String symbol,
    required Color iconColor,
  }) {
    bool isSelected = _selectedLanguageIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLanguageIndex = index),
        child: AnimatedScale(
          scale: isSelected ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 180,
            decoration: BoxDecoration(
              color: isSelected ? nthuPurple.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? nthuPurple : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: nthuPurple.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? iconColor.withOpacity(0.2)
                        : iconColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? nthuPurple : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Final Page: Confirmation ---
  Widget _buildFinalPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing / Scale-in animation for the final icon
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [nthuPurple.withOpacity(0.6), nthuPurple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: nthuPurple.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        const Text(
          "You're all set!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            "We will use your preferences to plan, filter, and recommend the best future courses tailored exactly to your needs.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // --- Bottom Information Card & Continue Button ---
  Widget _buildBottomSection() {
    String infoText = "";
    if (_currentStep == 0) {
      infoText =
          "Select your preferred time window to help us tailor your ideal academic schedule.";
    } else if (_currentStep == 1) {
      infoText =
          "Your credit load helps us measure your academic pace and build sustainable habits.";
    } else if (_currentStep == 2) {
      infoText =
          "Core courses demand more focus. We'll balance your routine to match your workload.";
    } else if (_currentStep == 3) {
      infoText =
          "Knowing your career goals helps us suggest relevant paths and skills to develop.";
    } else if (_currentStep == 4) {
      infoText =
          "We will use this to recommend General Elective (GE) courses you'll actually enjoy.";
    } else if (_currentStep == 5) {
      infoText =
          "This helps us filter and prioritize course recommendations in your preferred language.";
    }

    // Disable logic
    bool isButtonDisabled = false;
    if (_currentStep == 3 && _selectedCareers.isEmpty) {
      isButtonDisabled = true;
    }
    if (_currentStep == 4 && _selectedGECategories.isEmpty) {
      isButtonDisabled = true;
    }
    if (_currentStep == 5 && _selectedLanguageIndex == -1) {
      isButtonDisabled = true;
    }
    if (_isSavingPreferences) {
      isButtonDisabled = true;
    }

    final shouldShowInfoCard = _currentStep < _totalSteps - 1 &&
        _currentStep != 3 &&
        _currentStep != 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smooth fade in/out for the info card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: shouldShowInfoCard
                ? Container(
                    key: ValueKey<int>(_currentStep),
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: Colors.black54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          infoText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('empty_card')),
          ),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isButtonDisabled ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: nthuPurple,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSavingPreferences
                    ? const SizedBox(
                        key: ValueKey<String>('saving'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1 ? "Save" : "Continue",
                        key: ValueKey<int>(_currentStep),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
