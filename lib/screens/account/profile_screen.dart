import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:enthusiast/widgets/button_with_icon_widget.dart';
import 'widgets/header_menu_widget.dart';
import 'ccxp_login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../providers/ccxp_data_provider.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Define the scopes we need
  final List<String> _scopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.modify',
  ];

  void _navToCcxpLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CcxpLoginScreen()),
    );
  }

  Future<void> _handleEmailLogin() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // 1. Initialize with ONLY your Web Client ID. No scopes here!
      await googleSignIn.initialize(
        serverClientId:
            '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com',
      );

      // 2. Authenticate the user
      final GoogleSignInAccount? account = await googleSignIn.authenticate();

      if (account != null) {
        // 3. Request the Server Auth Code and PASS THE SCOPES HERE
        final GoogleSignInServerAuthorization? serverAuth = await account
            .authorizationClient
            .authorizeServer(_scopes);

        final String? serverAuthCode = serverAuth?.serverAuthCode;

        if (serverAuthCode != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Successfully linked Gmail!')),
            );
          }

          print("SUCCESS! Sending this code to Firebase: $serverAuthCode");

          try {
            // 1. Initialize Firebase Functions
            final functions = FirebaseFunctions.instance;
            final ccxpData = Provider.of<CcxpDataProvider>(
              context,
              listen: false,
            );

            if (ccxpData.graduationData == null ||
                ccxpData.graduationData!["studentInfo"] == null ||
                ccxpData.graduationData!["studentInfo"]["studentId"] == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Error: Could not find Student ID. Please log in to CCXP first.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return; // Stop the execution
            }

            final String currentStudentId = ccxpData
                .graduationData!["studentInfo"]["studentId"]
                .toString();
            // -------------------------------------
            // 2. Call the new backend function
            final result = await functions
                .httpsCallable('linkGmailAccount')
                .call({
                  'serverAuthCode': serverAuthCode,
                  'email': account.email,
                  'studentId': currentStudentId, // <--- ADDED THIS LINE
                });

            // 3. Handle the server response
            if (result.data['success'] == true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account successfully linked and secured!'),
                  ),
                );
              }
            } else {
              print("Backend warning: ${result.data['error']}");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Warning: No refresh token generated. Check console.',
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            print("Cloud Function Error: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to connect to server.')),
              );
            }
          }
        } else {
          print("Failed to get server auth code.");
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
      }
      print("Google Sign In Error: $error");
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
