import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/design_tokens.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'ui/screens/home_dashboard.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register web-safe global error boundaries to prevent unhandled JS-interop
  // exception casting errors (TypeError: FirebaseException is not a subtype of JavaScriptObject)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Web Global Error Boundary caught unhandled error: $error');
    // Return true to indicate error has been handled safely without red screen crash
    return true;
  };

  await dotenv.load(fileName: '.env');

  // Robust Firebase Web & Native initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FACEO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: DesignTokens.bgDeepBlack,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.accentPeriwinkle),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null && user.emailVerified) {
          return const HomeDashboard();
        }

        return const LoginScreen();
      },
    );
  }
}
