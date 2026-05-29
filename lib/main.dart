import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/ccxp_data_provider.dart';
import 'providers/language_provider.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

// 1. Import your screens f+or the Gatekeeper
import 'screens/main_screen.dart'; // Adjust path if necessary
import 'screens/preference/preference_screen.dart';   // Adjust path if necessary

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
    return LanguageProviderScope(
      child: ChangeNotifierProvider(
        create: (_) => CcxpDataProvider(),
        child: MaterialApp(
          title: 'eNTHUsiast App',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          // 2. Remove initialRoute and use the Gatekeeper as the home widget
          home: const GatekeeperScreen(),

          // 3. Keep your named routes intact for navigation later
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}

// 4. The Gatekeeper Widget
class GatekeeperScreen extends StatelessWidget {
  const GatekeeperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check the global variable from preference_screen.dart
    return hasShownPreferencesThisSession 
        ? const MainScreen() 
        : const PreferenceScreen();
  }
}