import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/routes/app_routes.dart';
import 'package:enthusiast/widgets/button_circle_back.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class CcxpLoginScreen extends StatefulWidget {
  const CcxpLoginScreen({super.key});

  @override
  State<CcxpLoginScreen> createState() => _CcxpLoginScreenState();
}

class _CcxpLoginScreenState extends State<CcxpLoginScreen> {
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final dio = Dio();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> registerFirebase({
    required String studentId,
    required String password,
    required final graduationData,
    required final schedule,
  }) async {
    String email = "$studentId@school.edu";

    try {
      // STEP 1: Create the user account in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Get the unique UID Firebase generated for this specific user
      String? uid = userCredential.user?.uid;

      if (uid != null) {
        // STEP 2: Connect the student data to this authentication account
        // We use the 'uid' as the Document ID so they are perfectly linked
        await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).set({
          'graduationData': graduationData,
          'scheduleData': schedule,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("Successfully authenticated and created profile for student!");
      }
    } on FirebaseAuthException catch (e) {
      // Handle weak password, email already in use, etc.
      print("Auth Error: ${e.message}");
    } catch (e) {
      // Handle database connection errors
      print("Database Error: $e");
    }
  }

  Future<Map<String, dynamic>> loginFirebase({
    required String studentId,
    required String password,
  }) async {
    final String email = "$studentId@school.edu";
    final String custPass = "$studentId@passqwert";
    String? uid;
    bool check = await _isCredentialCorrect(studentId, password);
    // if (!check) {
    //   throw Exception("Wrong credentials");
    // }
    try {
      // 1. Try signing into Firebase Auth
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: custPass);
      uid = credential.user?.uid;
      print("Login successful via Firebase Auth!");
    } on FirebaseAuthException catch (e) {
      // 2. If user doesn't exist in Firebase Auth, fetch from API and register them
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        print("User not found in Firebase. Fetching from API...");

        final apiData = await _fetchCcxpDataFromApi(studentId, password);

        // This registers them AND uploads their API data to Firestore using their new UID
        await registerFirebase(
          studentId: studentId,
          password: custPass,
          graduationData: apiData['graduationData'],
          schedule: apiData['scheduleData'],
        );

        // After successful registration, the user is already signed in by registerFirebase.
        // We just grab the current user UID.
        uid = FirebaseAuth.instance.currentUser?.uid;
      } else {
        // Rethrow other auth errors (e.g., wrong-password) directly
        rethrow;
      }
    }

    if (uid == null) {
      throw Exception('Authentication yielded an invalid user token.');
    }

    // 3. Fetch the student profile from Firestore using the UID
    final userDoc = await FirebaseFirestore.instance
        .collection('ccxpUsers')
        .doc(uid)
        .get();

    final userData = userDoc.data();
    if (userData == null) {
      throw Exception('Student database profile could not be found.');
    }

    return userData;
  }

  // Updated login UI mechanism triggered by your button
  void _handleLogin() async {
    if (_studentIdController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Student ID and Password'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;

    try {
      // Run our robust firebase login orchestrator
      final userData = await loginFirebase(
        studentId: studentId,
        password: password,
      );

      final graduationData =
          userData['graduationData'] as Map<String, dynamic>?;
      final schedule = userData['scheduleData'];

      // Send the data down to your global state provider
      if (graduationData != null && schedule != null) {
        if (mounted) {
          Provider.of<CcxpDataProvider>(
            context,
            listen: false,
          ).setData(graduationData: graduationData, scheduleData: schedule);
        }
      } else {
        throw Exception('Unable to parse retrieved CCXP data structure.');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, AppRoutes.mainScreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        // Friendly error messages depending on what broke
        String errorMsg = e.toString();
        if (e is FirebaseAuthException && e.code == 'wrong-password') {
          errorMsg = "Incorrect password. Please try again.";
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $errorMsg')));
      }
    }
  }

  Future<bool> _isCredentialCorrect(String studentId, String password) async {
    const url = 'https://prowler-underpaid-smudgy.ngrok-free.dev';
    final response = await dio.post(
      '$url/login',
      data: {'uid': studentId, 'pw': password},
    );

    if (response.statusCode == 200) {
      if (response.data['sessKey'] != null) {
        return true;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _fetchCcxpDataFromApi(
    String studentId,
    String password,
  ) async {
    const url = 'https://prowler-underpaid-smudgy.ngrok-free.dev';
    final response = await dio.post(
      '$url/login',
      data: {'uid': studentId, 'pw': password},
    );

    if (response.statusCode != 200) {
      throw Exception('Login API failed with status ${response.statusCode}.');
    }

    final loginData = _parseResponseData(response.data);
    if (loginData is! Map<String, dynamic> || loginData['sessKey'] == null) {
      throw Exception('Invalid login response from API.');
    }

    final sessKey = loginData['sessKey'];
    final gradResponse = await dio.post(
      '$url/graduationData',
      data: {'sessKey': sessKey},
    );
    final scheduleResponse = await dio.post(
      '$url/schedule',
      data: {'sessKey': sessKey},
    );

    if (gradResponse.statusCode != 200 || scheduleResponse.statusCode != 200) {
      throw Exception('Failed to fetch graduation or schedule data.');
    }

    final graduationData = _parseResponseData(gradResponse.data);
    final scheduleData = _parseResponseData(scheduleResponse.data);

    if (graduationData is! Map<String, dynamic>) {
      throw Exception('Invalid graduationData format from API.');
    }

    return {'graduationData': graduationData, 'scheduleData': scheduleData};
  }

  dynamic _parseResponseData(dynamic data) {
    if (data is String) {
      return jsonDecode(data);
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              // ── Background Header Gradient ─────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7E22CE), // NTHU Purple-ish
                        Color(0xFF3B82F6), // Blue accent
                      ],
                    ),
                  ),
                ),
              ),

              // ── Main Content ───────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // ── App Branding ───────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'eNTHUsiast',
                        style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Academic Information System (CCXP)',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 48),

                      // ── Login Form Card ────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign In',
                              style: GoogleFonts.dmSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Student ID Field
                            TextField(
                              controller: _studentIdController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.dmSans(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Student ID',
                                labelStyle: GoogleFonts.dmSans(
                                  color: const Color(0xFF6B7280),
                                ),
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: Color(0xFF9CA3AF),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E22CE),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              style: GoogleFonts.dmSans(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: GoogleFonts.dmSans(
                                  color: const Color(0xFF6B7280),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF9CA3AF),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _isPasswordVisible =
                                          !_isPasswordVisible,
                                    );
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF7E22CE),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7E22CE),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Login to CCXP',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Helpful Links ──────────────────────────────────────
                      TextButton(
                        onPressed: () {
                          // TODO: Open NTHU forgot password website
                        },
                        child: Text(
                          'Forgot your password?',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
