import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await _signInAnonymouslyIfNeeded();

  runApp(const LanguageProviderScope(child: MyApp()));
}

Future<void> _signInAnonymouslyIfNeeded() async {
  final FirebaseAuth auth = FirebaseAuth.instance;

  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.watch(context);

    return MaterialApp(
      title: 'eNTHUsiast App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: language.isChinese
          ? const Locale('zh', 'TW')
          : const Locale('en', 'US'),
      initialRoute: AppRoutes.mainScreen,
      routes: AppRoutes.routes,
    );
  }
}
