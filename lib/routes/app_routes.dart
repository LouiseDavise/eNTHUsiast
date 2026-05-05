import 'package:flutter/material.dart';

import '../screens/main_screen.dart'; 

class AppRoutes {
  // 2. Define the string names for your routes
  static const String mainScreen = '/main';
  // static const String tambahinSendiri = '/tambahin_sendiri';

  // 3. Create a map that connects the string to the actual Widget
  static Map<String, WidgetBuilder> get routes => {
    mainScreen: (context) => const MainScreen(),
    // tambahinSendiri: (context) => const TambahinSendiri(),
  };
}