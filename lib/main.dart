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
import 'screens/preference/preference_screen.dart'; // Adjust path if necessary
import 'package:enthusiast/screens/account/ccxp_login_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return StreamBuilder<User?>(
      // TIER 1: Check if a persistent user token exists on the device hardware
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // While Firebase is reading the device's secure storage keychain
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If no persistent session exists, route straight to the Login Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const CcxpLoginScreen(); // Your actual login view
        }

        final User user = authSnapshot.data!;

        // TIER 2: User is authenticated. Now pull their background Firestore profile data
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('ccxpUsers')
              .doc(user.uid)
              .get(),
          builder: (context, dbSnapshot) {
            if (dbSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Fallback to login if data corrupts or gets missing in Firestore
            if (dbSnapshot.hasError ||
                !dbSnapshot.hasData ||
                !dbSnapshot.data!.exists) {
              return const CcxpLoginScreen();
            }

            final userData = dbSnapshot.data!.data();
            final graduationData =
                userData?['graduationData'] as Map<String, dynamic>?;
            final schedule = userData?['scheduleData'];
            final preferences = userData?['preferences'];
            final hasCompletedPreferences =
                preferences is Map<String, dynamic> &&
                preferences['completed'] == true;

            if (graduationData != null && schedule != null) {
              // Hydrate your global Provider model so other pages can consume the data safely
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<CcxpDataProvider>(context, listen: false).setData(
                  graduationData: graduationData,
                  scheduleData: schedule,
                );
              });

              // TIER 3: Show preferences only until the user has saved them.
              return hasCompletedPreferences
                  ? const MainScreen()
                  : const PreferenceScreen();
            }

            return const CcxpLoginScreen();
          },
        );
      },
    );
  }
}
