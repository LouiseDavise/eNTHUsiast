import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:enthusiast/widgets/button_with_icon_widget.dart';
import 'package:enthusiast/routes/app_routes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enthusiast/widgets/button_circle_back.dart';
import 'widgets/transcript_card_widget.dart';
import 'widgets/header_menu_widget.dart';
import 'ccxp_login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _navToCcxpLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CcxpLoginScreen()),
    );
  }

  void _emailLoginPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email login screen coming soon!')),
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
              onTapFunc:
                  _navToCcxpLogin, // <-- Updated to navigate to the new screen
            ),
            const SizedBox(height: 16), // Added spacing between buttons
            ButtonWithIconWidget(
              btnName: "EMAIL Login",
              btnIcon: const Icon(Icons.email, color: Colors.white),
              btnIconBgColor: Colors.red,
              onTapFunc: _emailLoginPlaceholder, // <-- Updated to placeholder
            ),
          ],
        ),
      ),
    );
  }
}
