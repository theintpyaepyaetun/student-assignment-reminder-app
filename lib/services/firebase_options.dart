import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyForTestingOnly12345678901234567',
    appId: '1:123456789012:web:abcdef1234567890abcdef',
    messagingSenderId: '123456789012',
    projectId: 'student-assignment-demo',
    authDomain: 'student-assignment-demo.firebaseapp.com',
    databaseURL: 'https://student-assignment-demo.firebaseio.com',
    storageBucket: 'student-assignment-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyForTestingOnly12345678901234567',
    appId: '1:123456789012:android:abcdef1234567890abcdef',
    messagingSenderId: '123456789012',
    projectId: 'student-assignment-demo',
    databaseURL: 'https://student-assignment-demo.firebaseio.com',
    storageBucket: 'student-assignment-demo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyForTestingOnly12345678901234567',
    appId: '1:123456789012:ios:abcdef1234567890abcdef',
    messagingSenderId: '123456789012',
    projectId: 'student-assignment-demo',
    databaseURL: 'https://student-assignment-demo.firebaseio.com',
    storageBucket: 'student-assignment-demo.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDemoKeyForTestingOnly12345678901234567',
    appId: '1:123456789012:macos:abcdef1234567890abcdef',
    messagingSenderId: '123456789012',
    projectId: 'student-assignment-demo',
    databaseURL: 'https://student-assignment-demo.firebaseio.com',
    storageBucket: 'student-assignment-demo.appspot.com',
  );
}

// Helper to get default target platform
TargetPlatform get defaultTargetPlatform {
  if (kIsWeb) {
    return TargetPlatform.android; // Default for web
  }
  if (Platform.isAndroid) {
    return TargetPlatform.android;
  } else if (Platform.isIOS) {
    return TargetPlatform.iOS;
  } else if (Platform.isMacOS) {
    return TargetPlatform.macOS;
  } else if (Platform.isWindows) {
    return TargetPlatform.windows;
  }
  return TargetPlatform.linux;
}

enum TargetPlatform { android, iOS, macOS, windows, linux }
