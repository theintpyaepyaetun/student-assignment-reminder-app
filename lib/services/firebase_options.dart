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
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc',
    appId: '1:752057448311:web:1765e5f144d254b8ff1372',
    messagingSenderId: '752057448311',
    projectId: 'student-assignment-reminder',
    authDomain: 'student-assignment-reminder.firebaseapp.com',
    databaseURL: 'https://student-assignment-reminder.firebaseio.com',
    storageBucket: 'student-assignment-reminder.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc',
    appId: '1:752057448311:android:1765e5f144d254b8ff1372',
    messagingSenderId: '752057448311',
    projectId: 'student-assignment-reminder',
    databaseURL: 'https://student-assignment-reminder.firebaseio.com',
    storageBucket: 'student-assignment-reminder.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc',
    appId: '1:752057448311:ios:1765e5f144d254b8ff1372',
    messagingSenderId: '752057448311',
    projectId: 'student-assignment-reminder',
    databaseURL: 'https://student-assignment-reminder.firebaseio.com',
    storageBucket: 'student-assignment-reminder.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc',
    appId: '1:752057448311:macos:1765e5f144d254b8ff1372',
    messagingSenderId: '752057448311',
    projectId: 'student-assignment-reminder',
    databaseURL: 'https://student-assignment-reminder.firebaseio.com',
    storageBucket: 'student-assignment-reminder.firebasestorage.app',
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
