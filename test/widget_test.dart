// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_assignment_reminder_app/main.dart';
import 'package:student_assignment_reminder_app/services/firebase_service.dart';

void main() {
  testWidgets('App loads and shows login UI', (WidgetTester tester) async {
    // initialize FirebaseService for the test environment; this will
    // effectively be a no-op if options are still placeholders, but it
    // prevents AuthProvider from trying to access Firebase before an app
    // exists.
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseService.initialize();
    // Build the app inside a MediaQuery with a larger size to avoid layout overflows
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1080, 2340)),
        child: const StudentApp(),
      ),
    );

    // Allow frames to settle
    await tester.pumpAndSettle();

    // Verify that the login screen is shown with expected text
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
