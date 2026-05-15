import 'package:enthusiast/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:enthusiast/widgets/button_with_icon_widget.dart';
import 'package:enthusiast/routes/app_routes.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enthusiast/widgets/button_circle_back.dart';
import 'widgets/transcript_card_widget.dart';
import 'widgets/header_menu_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _ccxpLogin() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'CCXP Login',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _usernameController.clear();
                _passwordController.clear();
              },
              child: Text(
                'Back',
                style: GoogleFonts.dmSans(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                String username = _usernameController.text;
                String password = _passwordController.text;
                print("Login: $username");
                // Add your login logic here
                Navigator.pop(context);
                _usernameController.clear();
                _passwordController.clear();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text(
                'Confirm',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderMenuWidget(title: "Account", subTitle: "Account Login"),
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          children: [
            ButtonWithIconWidget(
              btnName: "CCXP Login",
              btnIcon: Icon(Icons.school),
              btnIconBgColor: Colors.purple,
              onTapFunc: _ccxpLogin,
            ),
            ButtonWithIconWidget(
              btnName: "EMAIL Login",
              btnIcon: Icon(Icons.email),
              btnIconBgColor: Colors.red,
              onTapFunc: _ccxpLogin,
            ),
          ],
        ),
      ),
    );
  }
}
