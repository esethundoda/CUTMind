import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth/signin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CUTMindApp());
}

class CUTMindApp extends StatelessWidget {
  const CUTMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUTMind',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppRoot(),
    );
  }
}

/// Shows the onboarding once, then hands over to the auth gate.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  static const _prefKey = 'onboarding_seen';
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _seen = prefs.getBool(_prefKey) ?? false);
    } catch (_) {
      if (mounted) setState(() => _seen = true);
    }
  }

  Future<void> _finish() async {
    setState(() => _seen = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) return const _Splash();
    if (_seen == false) return OnboardingScreen(onFinished: _finish);
    return const _AuthGate();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Icon(Icons.psychology_alt,
              size: 50, color: Colors.white),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        if (snapshot.hasData) return const HomeScreen();
        return const SignInScreen();
      },
    );
  }
}
