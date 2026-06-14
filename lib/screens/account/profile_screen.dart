import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:enthusiast/widgets/button_with_icon_widget.dart';
import 'widgets/header_menu_widget.dart';
import 'ccxp_login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../providers/ccxp_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com'
        : null,
    serverClientId: kIsWeb
        ? null
        : '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  void _navToCcxpLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CcxpLoginScreen()),
    );
  }

  String? _getStudentId() {
    final ccxpData = Provider.of<CcxpDataProvider>(context, listen: false);
    final studentId =
        ccxpData.graduationData?["studentInfo"]?["studentId"]?.toString();
    if (studentId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: Could not find Student ID. Please log in to CCXP first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return studentId;
  }

  Future<void> _callLinkFunction(Map<String, dynamic> payload) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Error: Not logged in to Firebase. Please log in to CCXP first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final fullPayload = {...payload, 'uid': uid};

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('linkGmailAccount')
          .call(fullPayload);

      if (!mounted) return;

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account successfully linked and secured!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: Linking completed but check the console.'),
          ),
        );
      }
    } catch (e) {
      print("Cloud Function Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to server.')),
        );
      }
    }
  }

  Future<void> _handleEmailLoginMobile() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return;

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? serverAuthCode = auth.serverAuthCode;

      if (serverAuthCode == null) {
        print("Failed to get server auth code.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to get server auth code. Check serverClientId configuration.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully authorized Gmail! Linking...'),
          ),
        );
      }

      final studentId = _getStudentId();
      if (studentId == null) return;

      await _callLinkFunction({
        'serverAuthCode': serverAuthCode,
        'email': account.email,
        'studentId': studentId,
        'platform': 'mobile',
      });
    } catch (error) {
      print("Google Sign In Error (mobile): $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $error')),
        );
      }
    }
  }

  Future<void> _handleEmailLoginWeb() async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return;

      final bool granted =
          await _googleSignIn.requestScopes(_googleSignIn.scopes.toList());
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gmail scope not granted.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      account = await _googleSignIn.signInSilently() ?? account;
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;

      if (accessToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get access token.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully authorized Gmail! Linking...'),
          ),
        );
      }

      final studentId = _getStudentId();
      if (studentId == null) return;

      await _callLinkFunction({
        'accessToken': accessToken,
        'email': account.email,
        'studentId': studentId,
        'platform': 'web',
      });
    } catch (e) {
      print("Web Google Sign In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization failed: $e')),
        );
      }
    }
  }

  Future<void> _handleEmailLogin() async {
    if (_isMobilePlatform) {
      await _handleEmailLoginMobile();
    } else {
      await _handleEmailLoginWeb();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HeaderMenuWidget(
        title: "Account",
        subTitle: "Account Login",
      ),
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          children: [
            ButtonWithIconWidget(
              btnName: "CCXP Login",
              btnIcon: const Icon(Icons.school, color: Colors.white),
              btnIconBgColor: Colors.purple,
              onTapFunc: _navToCcxpLogin,
            ),
            const SizedBox(height: 16),
            ButtonWithIconWidget(
              btnName: "EMAIL Login",
              btnIcon: const Icon(Icons.email, color: Colors.white),
              btnIconBgColor: Colors.red,
              onTapFunc: _handleEmailLogin,
            ),
          ],
        ),
      ),
    );
  }
}