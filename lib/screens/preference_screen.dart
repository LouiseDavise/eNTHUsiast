import 'package:flutter/material.dart';
import 'main_screen.dart';

// Global variable that resets to false on every Hot Restart
bool hasShownPreferencesThisSession = false;

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  static const Color nthuPurple = Color(0xFF7A3392);
  
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Q1 State: 480 mins (08:00) to 1280 mins (21:20)
  RangeValues _timeRange = const RangeValues(480, 1280);

  // Q2 State: 0: <16, 1: 16-18, 2: 19-21, 3: 22-25
  int _selectedCreditIndex = 1;
  final List<String> _creditOptions = ['< 16', '16 - 18', '19 - 21', '22 - 25'];

  // Q3 State: 0 to 8
  double _coreCourses = 4;

  @override
  void initState() {
    super.initState();
    // Mark as shown so it doesn't appear again during this hot restart lifecycle
    hasShownPreferencesThisSession = true;
  }

  // Helper to format minutes into HH:MM
  String _formatTime(double totalMinutes) {
    int h = (totalMinutes ~/ 60).toInt();
    int m = (totalMinutes % 60).toInt();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      // Optional: Pop if they back out of the very first screen
      // Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildCurrentQuestion(),
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _previousStep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(nthuPurple),
              ),
            ),
          ),
          const SizedBox(width: 32), // Balance the back button
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
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Question 1: Time Window ---
  Widget _buildTimeQuestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "What time is most comfortable to you in a day?",
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
          "${_formatTime(_timeRange.start)}  -  ${_formatTime(_timeRange.end)}",
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
            values: _timeRange,
            min: 480, // 08:00
            max: 1280, // 21:20
            divisions: 80, // 10-minute increments
            onChanged: (RangeValues values) {
              setState(() {
                _timeRange = values;
              });
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("08:00", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text("21:20", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
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
          "How many credits?",
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isSelected ? nthuPurple.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? nthuPurple : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _creditOptions[index],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? nthuPurple : Colors.black87,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, color: nthuPurple),
                ],
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
          "How many core courses?",
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
            onChanged: (value) {
              setState(() {
                _coreCourses = value;
              });
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("0", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text("8", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Bottom Information Card & Continue Button ---
  Widget _buildBottomSection() {
    String infoText;
    if (_currentStep == 0) {
      infoText = "Select a time window to let us build a comfortable study routine for you.";
    } else if (_currentStep == 1) {
      infoText = "We use your credit load to measure progress and pace your weekly habits.";
    } else {
      infoText = "Core courses require more energy. We'll balance your schedule accordingly.";
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, color: Colors.black54),
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
          ),
          const SizedBox(height: 24),
          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: nthuPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                _currentStep == _totalSteps - 1 ? "Finish" : "Continue",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}