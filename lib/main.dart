import 'package:flutter/material.dart';
import 'routes/app_routes.dart'; // Import your routes
import 'theme/app_theme.dart'; // Import the theme we just fixed

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eNTHUsiast App',
      debugShowCheckedModeBanner: false,
      
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      
      initialRoute: AppRoutes.mainScreen, 
      
      routes: AppRoutes.routes, 
    );
  }
}