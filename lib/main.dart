import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'landing_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/assignment_provider.dart';
import 'providers/task_provider.dart';
import 'services/assignment_notification_service.dart';
import 'services/firebase_service.dart';
import 'services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await AssignmentNotificationService.instance.initialize();
  if (!kIsWeb) {
    await FirebaseMessagingService().initialize();
  }
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  String _resolveInitialRoute() {
    final path = Uri.base.path.toLowerCase();
    if (path == '/signup') return '/signup';
    if (path == '/home') return '/home';
    if (path == '/login') return '/login';

    final screen = Uri.base.queryParameters['screen']?.toLowerCase();
    if (screen == 'signup') return '/signup';
    if (screen == 'home') return '/home';
    return '/login';
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AssignmentProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: '.SF Pro Display'),
        initialRoute: _resolveInitialRoute(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/signup':
              return MaterialPageRoute(builder: (_) => const SignUpScreen());
            case '/landing':
              return MaterialPageRoute(builder: (_) => const LandingScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}
