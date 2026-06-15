import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/routes/app_routes.dart';
import 'package:enthusiast/widgets/button_circle_back.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:ui';

const bool prod = false;

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
    required String email,
    required String password,
    required final graduationData,
    required final schedule,
    // required final pw,
  }) async {
    // String email = "$studentId@school.edu";

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
    String? uid;
    dynamic userDoc = null;
    dynamic userData = null;
    // bool check = await _isCredentialCorrect(studentId, password);
    // if (!check) {
    //   throw Exception("Wrong credentials");
    // }

    // 1. Try signing into Firebase Auth
    final snapshot = await FirebaseFirestore.instance
        .collection('ccxpUsers')
        .where('graduationData.studentInfo.studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    print(snapshot.docs.isEmpty);
    if (snapshot.docs.isEmpty) {
      print("User not found in Firebase. Fetching from API...");

      final apiData = await fetchCcxpDataFromApi(studentId, password);

      // final newPw = hashPassword(password);
      // This registers them AND uploads their API data to Firestore using their new UID
      await registerFirebase(
        email: email,
        password: hashPassword(password),
        graduationData: apiData['graduationData'],
        schedule: apiData['scheduleData'],
        // pw: newPw,
      );

      // After successful registration, the user is already signed in by registerFirebase.
      // We just grab the current user UID.
      uid = FirebaseAuth.instance.currentUser?.uid;
    } else {
      try {
        UserCredential credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: hashPassword(password),
        );
        uid = credential.user?.uid;
        userDoc = await FirebaseFirestore.instance
            .collection('ccxpUsers')
            .doc(uid)
            .get();
        userData = userDoc.data();
      } on FirebaseAuthException catch (e) {
        rethrow;
      }
    }

    // 3. Fetch the student profile from Firestore using the UID
    userDoc =
        await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).get();

    userData = userDoc.data();
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
      print(userData);

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
      // if (e is FirebaseAuthException && e.code == 'wrong-password') {
      //   await FirebaseAuth.instance.signOut();

      //   if (!mounted) return;
      //   // print("inside catch block");

      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text("Incorrect password. Please try again."),
      //     ),
      //   );
      //   return;
      // }
      if (mounted) {
        print("not logged in");
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

  Future<Map<String, dynamic>> refreshData({
    required String studentId,
    required String password,
  }) async {
    final apiData = await fetchCcxpDataFromApi(studentId, password);
    final graduationData = apiData['graduationData'];
    final schedule = apiData['schedule'];

    final String email = "$studentId@school.edu";
    final String custPass = "$studentId@passqwert";
    UserCredential credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: custPass);
    final uid = credential.user?.uid;
    await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).set({
      'graduationData': graduationData,
      'scheduleData': schedule,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userDoc =
        await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).get();

    final userData = userDoc.data();
    if (userData == null) {
      throw Exception('Student database profile could not be found.');
    }

    return userData;
  }

  void _handleRefresh() async {
    setState(() => _isLoading = true);
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;
    try {
      // Run our robust firebase login orchestrator
      final userData = await refreshData(
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

  // Future<bool> _isCredentialCorrect(String studentId, String password) async {
  //   const url = 'https://prowler-underpaid-smudgy.ngrok-free.dev';
  //   final response = await dio.post(
  //     '$url/login',
  //     data: {'uid': studentId, 'pw': password},
  //   );

  //   if (response.statusCode == 200) {
  //     if (response.data['sessKey'] != null) {
  //       return true;
  //     }
  //   }
  //   return false;
  // }

  String hashPassword(String pw) {
    return sha256.convert(utf8.encode(pw)).toString();
  }

  Future<Map<String, dynamic>> fetchCcxpDataFromApi(
    String studentId,
    String password,
  ) async {
    const url = prod
        ? 'https://us-central1-enthusiast-e3429.cloudfunctions.net/api'
        : 'https://prowler-underpaid-smudgy.ngrok-free.dev';
    final response = await dio.post(
      '$url/login',
      data: {'uid': studentId, 'pw': password},
    );

    print("login succeed");

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _LoginColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: 24 + bottomInset),
        child: Column(
          children: [
            const _HeroHeader(),
            Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _buildLoginCard(),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -22),
              child: TextButton(
                onPressed: () {
                  // TODO: Open NTHU forgot password website.
                },
                style: TextButton.styleFrom(
                  foregroundColor: _LoginColors.mutedText,
                ),
                child: Text(
                  'Forgot your password?',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.deepPurple.withValues(alpha: 0.14),
            blurRadius: 36,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in to CCXP',
            style: GoogleFonts.dmSans(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: _LoginColors.primaryText,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access your academic records, schedule, and graduation progress.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _LoginColors.mutedText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          _AnimatedLoginField(
            controller: _studentIdController,
            label: 'Student ID',
            hintText: 'Enter your student ID',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 14),
          _AnimatedLoginField(
            controller: _passwordController,
            label: 'Password',
            hintText: 'Enter your CCXP password',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _handleLogin(),
            suffixIcon: IconButton(
              tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: _LoginColors.mutedText,
                size: 21,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _TrustRow(),
          const SizedBox(height: 24),
          _GradientLoginButton(
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleLogin,
          ),
        ],
      ),
    );
  }
}

class _LoginColors {
  static const background = Color(0xFFF6F3FB);
  static const primaryPurple = Color(0xFF7B2CBF);
  static const deepPurple = Color(0xFF5A189A);
  static const royalPurple = Color(0xFF3C096C);
  static const blue = Color(0xFF5A189A);
  static const primaryText = Color(0xFF111827);
  static const mutedText = Color(0xFF5B6172);
  static const border = Color(0xFFE5E0EE);
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: 292 + topPadding,
      padding: EdgeInsets.fromLTRB(24, topPadding + 34, 24, 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LoginColors.royalPurple,
            _LoginColors.primaryPurple,
            _LoginColors.blue,
          ],
          stops: [0.0, 0.54, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(38),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -48,
            left: -60,
            child: _GlowCircle(
              size: 180,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            right: -84,
            bottom: -34,
            child: _GlowCircle(
              size: 220,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'eNTHUsiast',
                  style: GoogleFonts.dmSans(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Academic Information System (CCXP)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.94),
                    letterSpacing: 0.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _AnimatedLoginField extends StatefulWidget {
  const _AnimatedLoginField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<_AnimatedLoginField> createState() => _AnimatedLoginFieldState();
}

class _AnimatedLoginFieldState extends State<_AnimatedLoginField> {
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode()
      ..addListener(() {
        setState(() {
          _hasFocus = _focusNode.hasFocus;
        });
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor =
        _hasFocus ? _LoginColors.primaryPurple : _LoginColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _hasFocus ? Colors.white : const Color(0xFFFAFAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activeColor, width: _hasFocus ? 1.5 : 1),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: _LoginColors.primaryPurple.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        style: GoogleFonts.dmSans(
          color: _LoginColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          labelStyle: GoogleFonts.dmSans(
            color:
                _hasFocus ? _LoginColors.primaryPurple : _LoginColors.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          hintStyle: GoogleFonts.dmSans(
            color: const Color(0xFF8B91A3),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _hasFocus
                ? _LoginColors.primaryPurple
                : const Color(0xFF9CA3AF),
            size: 22,
          ),
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _LoginColors.primaryPurple.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: _LoginColors.deepPurple,
            size: 16,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Secure student authentication',
            style: GoogleFonts.dmSans(
              color: _LoginColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_LoginColors.primaryPurple, _LoginColors.deepPurple],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.deepPurple.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Text(
                      'LOGIN TO CCXP',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
