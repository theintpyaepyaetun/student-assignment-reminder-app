import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:student_assignment_reminder_app/screens/landing_screen.dart';
import 'package:student_assignment_reminder_app/screens/login_screen.dart';
import 'package:student_assignment_reminder_app/screens/signup_screen.dart';
import 'package:student_assignment_reminder_app/screens/home_screen.dart';
import 'package:student_assignment_reminder_app/providers/auth_provider.dart';
import 'package:student_assignment_reminder_app/providers/assignment_provider.dart';
import 'package:student_assignment_reminder_app/providers/task_provider.dart';
import 'package:student_assignment_reminder_app/services/assignment_notification_service.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _setupLocalTimezone() async {
  tz.initializeTimeZones();
  try {
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
    debugPrint('🌍 main() timezone initialized: $timezoneName');
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('UTC'));
    debugPrint('⚠️ main() timezone fallback to UTC: $e');
  }
}

Future<void> _configureFirestoreOfflinePersistence() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('✅ Firestore offline persistence configured in main()');
  } catch (e) {
    debugPrint('⚠️ Firestore offline persistence setup skipped: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setupLocalTimezone();
  String? startupError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _configureFirestoreOfflinePersistence();
  } catch (e) {
    startupError = e.toString();
    debugPrint('⚠️ Startup warning: $startupError');
  }

  if (!kIsWeb && startupError == null) {
    try {
      AssignmentNotificationService.instance.setNavigatorKey(appNavigatorKey);
      await AssignmentNotificationService.instance.initialize();
    } catch (e) {
      debugPrint('⚠️ Notifications init skipped: $e');
    }
  }
  // Firebase Messaging initialization is skipped at app startup because
  // token retrieval can fail on some devices and stop the app from launching.
  // It can be re-enabled later after the device/Firebase setup is stable.
  runApp(StudentApp(startupError: startupError));
}

class StudentApp extends StatelessWidget {
  final String? startupError;

  const StudentApp({super.key, this.startupError});

  String _resolveInitialRoute() {
    final hasActiveSession = FirebaseAuth.instance.currentUser != null;
    final path = Uri.base.path.toLowerCase();
    final screen = Uri.base.queryParameters['screen']?.toLowerCase();

    // If on /app, go to app logic, else show landing
    if (path == '/app' || path.startsWith('/app')) {
      if (screen == 'login') return '/login';
      if (screen == 'signup') return '/signup';
      if (screen == 'home') return '/home';
      if (hasActiveSession) return '/home';
      return '/login';
    }
    // Default: show landing page
    return '/landing';
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
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: '.SF Pro Display'),
        initialRoute: _resolveInitialRoute(),
        builder: (context, child) {
          if (startupError == null) return child ?? const SizedBox.shrink();

          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Firebase initialization failed. Check Firebase web config and authorized domains.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => LoginScreen());
            case '/signup':
              return MaterialPageRoute(builder: (_) => SignUpScreen());
            case '/landing':
              return MaterialPageRoute(builder: (_) => LandingScreen());
            case '/home':
              final args = settings.arguments;
              String? assignmentId;
              if (args is Map) {
                assignmentId = args['assignmentId']?.toString();
              }
              return MaterialPageRoute(
                builder: (_) => HomeScreen(initialAssignmentId: assignmentId),
              );
            default:
              // If on /app, default to login, else landing
              final path = Uri.base.path.toLowerCase();
              if (path == '/app' || path.startsWith('/app')) {
                return MaterialPageRoute(builder: (_) => LoginScreen());
              }
              return MaterialPageRoute(builder: (_) => LandingScreen());
          }
        },
      ),
    );
  }
}
