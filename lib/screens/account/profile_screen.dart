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

// renderButton() lives in web_only.dart — must be imported directly.
// The conditional import swaps in a no-op stub on mobile so it compiles.
import 'package:google_sign_in_web/web_only.dart' as gsi_web
    if (dart.library.io) 'stub_gsi_web.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> _scopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
  ];

  static const String _clientId =
      '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com';

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  bool _webSignInPending = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On web, sign-in is triggered by the rendered Google button.
      // We listen to authenticationEvents to know when the user has signed in.
      GoogleSignIn.instance
          .initialize(clientId: _clientId)
          .then((_) {
            GoogleSignIn.instance.authenticationEvents
                .listen(_handleWebAuthEvent)
                .onError((e) => print("Web auth stream error: $e"));
          });
    }
  }

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
    // uid is the Firebase Auth UID — this is the Firestore doc key in ccxpUsers
    // Uid adalah Firebase Auth UID — ini adalah kunci doc Firestore di ccxpUsers
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Not logged in to Firebase. Please log in to CCXP first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Merge uid into the payload before sending to Cloud Function
    // Gabungkan uid ke payload sebelum dikirim ke Cloud Function
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

  // ---------------------------------------------------------------------------
  // WEB: authenticationEvents emits GoogleSignInAuthenticationEvent,
  // so we extract .user from the event (not cast it directly as an account).
  // ---------------------------------------------------------------------------
  Future<void> _handleWebAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (!_webSignInPending) return;
    _webSignInPending = false;

    // Close the dialog if it's still open
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // GoogleSignInAuthenticationEvent is sealed — must switch on its subtype to get the account.
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final GoogleSignInAccount account = event.user;

    try {
      // authorizeScopes() is the v7 way to get an accessToken on web
      final GoogleSignInClientAuthorization auth =
          await account.authorizationClient.authorizeScopes(_scopes);

      final String accessToken = auth.accessToken;

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
      print("Web scope auth error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization failed: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MOBILE: unchanged original v7.2.0 flow using serverAuthCode
  // ---------------------------------------------------------------------------
  Future<void> _handleEmailLoginMobile() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize(
        clientId: _clientId,
        serverClientId: _clientId,
      );

      final GoogleSignInAccount? account = await googleSignIn.authenticate();
      if (account == null) return;

      final GoogleSignInServerAuthorization? serverAuth =
          await account.authorizationClient.authorizeServer(_scopes);

      final String? serverAuthCode = serverAuth?.serverAuthCode;
      if (serverAuthCode == null) {
        print("Failed to get server auth code.");
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

  Future<void> _handleEmailLogin() async {
    if (_isMobilePlatform) {
      await _handleEmailLoginMobile();
    } else {
      _webSignInPending = true;
      _showWebSignInDialog();
    }
  }

  // Shows a dialog with the real Google-rendered button.
  // v7 on web requires this — programmatic sign-in is not supported.
  void _showWebSignInDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign in with Google'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tap the button below to link your Gmail account.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // renderButton() is from google_sign_in_web/web_only.dart
            // It renders Google's own sign-in button — required by the GIS SDK.
            gsi_web.renderButton(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _webSignInPending = false;
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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