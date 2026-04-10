# Firebase Cloud Messaging (FCM) Setup Guide

## What Was Done

Your app is now configured for **Firebase Cloud Messaging** which is required for Google Play Store submission. Here's what was added:

### 1. **Dependencies Updated** (`pubspec.yaml`)
- Added `firebase_messaging: ^14.7.0` to handle push notifications from Firebase

### 2. **New Service Created** (`lib/services/firebase_messaging_service.dart`)
- Handles all FCM initialization and message handling
- Manages foreground notifications (when app is open)
- Handles background notifications (when app is closed)
- Requests notification permissions from users
- Retrieves and manages FCM tokens

### 3. **Updated Notification Service** (`lib/services/assignment_notification_service.dart`)
- Added `showLocalNotification()` method to display notifications from FCM messages
- Integrates FCM messages with your existing local notification system

### 4. **Updated Main App** (`lib/main.dart`)
- Added Firebase Messaging Service initialization on app startup

## Next Steps for Google Play Store

### 1. **Enable Cloud Messaging in Firebase Console**
   - Go to Firebase Console → Your Project
   - Navigate to **Cloud Messaging** tab
   - Ensure it shows "Cloud Messaging" is enabled
   - Copy your **Server Key** (needed to send messages from backend)

### 2. **Configure Android in Firebase Console**
   - Go to Project Settings → General
   - Download the updated `google-services.json`
   - Replace it in `android/app/google-services.json`

### 3. **Rebuild Your App**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk  # or flutter build appbundle for Play Store
   ```

### 4. **Test FCM on Your Device**
   - Run the app and check logcat for the FCM token
   - Use Firebase Console's "Send Test Message" to send a notification
   - The app should display the notification

### 5. **Add Backend Capability (Optional)**
   If you want to send notifications from your backend:
   - Use Firebase Admin SDK with your Server Key
   - Example endpoint to send notifications:
   ```javascript
   // Example Node.js backend
   const admin = require('firebase-admin');
   
   async function sendNotification(userId, title, body) {
     const userDoc = await admin.firestore().collection('users').doc(userId).get();
     const fcmToken = userDoc.data().fcmToken;
     
     await admin.messaging().send({
       notification: { title, body },
       token: fcmToken,
     });
   }
   ```

### 6. **Store FCM Token in Firestore**
   Modify your user creation/login to save FCM token:
   ```dart
   // In your login/signup logic
   final token = await FirebaseMessagingService().getFCMToken();
   await firestore.collection('users').doc(userId).set({
     'fcmToken': token,
     // ... other user data
   });
   ```

## How It Works

### Foreground Messages (App is Open)
1. Firebase receives the message
2. `FirebaseMessaging.onMessage` listener triggers
3. `showLocalNotification` displays it to the user

### Background Messages (App is Closed)
1. Firebase receives the message
2. Android system displays the notification
3. When user taps it, `FirebaseMessaging.onMessageOpenedApp` triggers
4. Navigation can be handled based on message data

## Testing in Firebase Console

1. Start your app
2. Check the logs for: `FCM Token: ...`
3. In Firebase Console → Cloud Messaging → Send Test Message
4. Select your app and paste the FCM token
5. Click "Send"

## Google Play Store Requirements

✅ Your app now has:
- Push notification capability (required for Play Store)
- User permission requests (respects Android 13+ requirements)
- Background message handling (critical for Play Store approval)
- Foreground message handling (good UX)

## Important Notes

- **FCM Token Changes**: Users get a new token when they reinstall or clear app data
- **Permissions**: The app requests permission automatically on first launch
- **Background Handler**: Messages can be processed even if the app is terminated
- **Offline**: Messages are queued and delivered when device comes online

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App not receiving notifications | Check Firebase Console for errors, verify FCM token in app logs |
| Notifications not showing in foreground | Foreground permission might not be granted, check app permissions |
| Token always changes | Normal behavior for development, tokens persist on installed apps |
| Build errors | Run `flutter clean && flutter pub get` before rebuilding |
