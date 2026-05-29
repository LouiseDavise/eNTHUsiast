import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import 'firebase_options.dart';
import 'providers/ccxp_data_provider.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is not supported on Linux, so only initialize on other platforms
  // if (!Platform.isLinux) {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // }
  print("main started");
  runApp(const MyApp());
  print("runApp called");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CcxpDataProvider(),
      child: MaterialApp(
        title: 'eNTHUsiast App',
        debugShowCheckedModeBanner: false,

        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,

        initialRoute: AppRoutes.mainScreen,

        routes: AppRoutes.routes,
      ),
    );
  }
}
