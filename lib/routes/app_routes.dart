import 'package:enthusiast/screens/account/language_screen.dart';
import 'package:enthusiast/screens/account/transcript_screen.dart';
import 'package:flutter/material.dart';

import '../screens/main_screen.dart';
import 'package:enthusiast/screens/account/profile_screen.dart';
import 'package:enthusiast/screens/account/account_screen.dart';

class AppRoutes {
  // 2. Define the string names for your routes
  static const String mainScreen = '/main';
  static const String profileScreen = '/account/profile';
  static const String accountScreen = '/account';
  static const String transcriptScreen = '/account/transcript';
  static const String languageScreen = '/account/language';
  // static const String tambahinSendiri = '/tambahin_sendiri';

  // 3. Create a map that connects the string to the actual Widget
  static Map<String, WidgetBuilder> get routes => {
    mainScreen: (context) => const MainScreen(),
    profileScreen: (context) => const ProfileScreen(),
    accountScreen: (context) => const AccountScreen(),
    transcriptScreen: (context) => const TranscriptScreen(),
    languageScreen: (context) => const LanguageScreen(),

    // tambahinSendiri: (context) => const TambahinSendiri(),
  };
}
