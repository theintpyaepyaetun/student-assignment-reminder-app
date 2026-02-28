# Firebase Setup Guide

## Overview
Your Student Assignment Reminder app is now integrated with Firebase for:
- **Authentication**: Firebase Auth (email/password)
- **Database**: Firebase Realtime Database (assignments & user data)
- **Offline Support**: Automatic offline persistence enabled

> **Demo mode notice:** if `lib/services/firebase_options.dart` still contains
> the placeholder values (e.g. strings starting with `YOUR_`), the app
> automatically falls back to a built‑in demo mode. In demo mode no network
> requests are made and any email/password combination will successfully log
> you in. Once you update the file with real Firebase credentials the app
> switches to using the live services.

## Setup Steps

### 1. Create a Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Create a new project** or select existing
3. Name it `student-assignment-reminder-app`
4. Enable Google Analytics (optional)
5. Click **Create project** and wait for initialization

### 2. Get Firebase Credentials

#### For Web/Android/iOS:
1. In Firebase Console, click **Project Settings** (gear icon)
2. Go to **Your apps** section
3. Click to add platform:
   - For Android: Select **Android**, enter package name `com.example.student_assignment_reminder_app`
   - For iOS: Select **iOS**, enter bundle ID `com.example.studentAssignmentReminderApp`
   - For Web: Select **Web**
4. Download the config file or copy credentials

### 3. Update Firebase Configuration

Edit `lib/services/firebase_options.dart` and replace placeholders with your Firebase credentials:

```dart
// Get these values from Firebase Console > Project Settings
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'YOUR_PROJECT_ID',
  databaseURL: 'https://YOUR_PROJECT_ID.firebaseio.com',
  storageBucket: 'YOUR_STORAGE_BUCKET',
);
```

### 4. Enable Authentication

In Firebase Console:
1. Go to **Authentication** > **Sign-in method**
2. Enable **Email/Password**
3. (Optional) Enable **Google Sign-In**

### 5. Setup Realtime Database

In Firebase Console:
1. Go to **Realtime Database**
2. Click **Create Database**
3. Start in **Test mode** (for development)
4. Choose location close to you
5. Click **Enable**

### 6. Configure Database Rules

Set the following security rules in Firebase Console > Realtime Database > Rules:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "assignments": {
          ".indexOn": ["createdAt", "dueDate"]
        }
      }
    }
  }
}
```

### 7. Platform-Specific Setup

#### Android
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory
3. The build.gradle is already configured

#### iOS
1. Download `GoogleService-Info.plist` from Firebase Console
2. Open `ios/Runner.xcworkspace` in Xcode
3. Drag `GoogleService-Info.plist` into Xcode (check "Copy items if needed")
4. Ensure it's added to Runner target

#### macOS
1. Download `GoogleService-Info.plist` from Firebase Console
2. Open `macos/Runner.xcworkspace` in Xcode
3. Drag `GoogleService-Info.plist` into Xcode

### 8. Run the App

```bash
flutter clean
flutter pub get
flutter run
```

## Database Structure

Your app uses the following Realtime Database structure:

```
users/
  {uid}/
    assignments/
      {assignmentId}/
        title: string
        description: string
        dueDate: string
        priority: string (low/medium/high)
        status: string (pending/completed/overdue)
        completed: boolean
        createdAt: timestamp
```

## Authentication

The app supports:
- **Sign Up**: Create new account with email/password
- **Login**: Existing users with email/password
- **Logout**: Clear session and return to login
- **Auto-login**: App checks if user is already authenticated on startup

## Offline Support

The Firebase Realtime Database is configured with offline persistence:
- Changes sync when connection is restored
- User can continue working offline
- Data persists across app restarts

## Troubleshooting

### Build Error: "google-services.json not found"
- Ensure `google-services.json` is in `android/app/` directory
- Run `flutter clean && flutter pub get`

### "Authentication failed" during login
- Check credentials in Firebase console
- Ensure Email/Password authentication is enabled
- Verify user exists in Firebase Auth console

### Database rules error (403 Permission Denied)
- Review and update security rules in Firebase Console
- Ensure user UID in rules matches authenticated user

### Offline issues
- Persistence is enabled by default
- Check that device has storage space
- Clear app cache if issues persist: `flutter clean`

## Next Steps

1. Customize Firebase options for production
2. Add error logging and analytics
3. Set up Firebase Cloud Functions for backend logic
4. Enable backup and recovery options
5. Monitor usage in Firebase Console

## Resources

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com)
- [Realtime Database Security Rules](https://firebase.google.com/docs/rules)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
