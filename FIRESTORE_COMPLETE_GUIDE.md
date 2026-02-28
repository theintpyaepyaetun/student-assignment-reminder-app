# Firebase Cloud Firestore Setup - Complete Guide

## 🎯 Overview
This document provides complete instructions for your Student Assignment Reminder App's Firebase integration with Cloud Firestore for user authentication, user-specific data storage, and security.

## 📋 Features Implemented

### ✅ User Authentication
- **Sign Up**: Create new accounts with email/password
- **Login**: Authenticate existing users
- **Firebase Auth Integration**: Primary authentication method
- **Local Fallback**: Offline authentication backup using SharedPreferences

### ✅ User-Specific Data
- **User Profiles**: Stored in Cloud Firestore under `users/{uid}`
- **Real-time Updates**: Settings screen uses StreamBuilder for live data
- **Preferences Management**: Theme, notifications, language settings
- **Profile Management**: Username, email, photo URL storage

### ✅ Profile/Settings Page
- **Display User Data**: Shows username, email, profile photo from Firestore
- **Edit Preferences**: Update notification settings in real-time
- **Glassmorphic Design**: Beautiful UI with backdrop filters

### ✅ Security
- **Firestore Security Rules**: User can only read/write their own data
- **Authentication Check**: All operations verify current user
- **UID-based Access Control**: Documents keyed by Firebase Auth UID

## 🗄️ Database Structure

### Firestore Collection: `users`

```
Firestore
└── users (collection)
    └── {uid} (document)
        ├── email: string
        ├── username: string
        ├── photoUrl: string | null
        ├── preferences: map
        │   ├── theme: "light" | "dark"
        │   ├── notifications: true | false
        │   └── language: "en" | "es" | "fr" etc.
        ├── createdAt: Timestamp
        └── updatedAt: Timestamp
```

**Example Document:**
```json
{
  "uid": "abc123xyz",
  "email": "student@university.edu",
  "username": "John Doe",
  "photoUrl": null,
  "preferences": {
    "theme": "light",
    "notifications": true,
    "language": "en"
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

## 🔒 Firestore Security Rules

**CRITICAL: You must add these security rules to your Firebase Console.**

### How to Add Security Rules:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **student-assignment-reminder**
3. Navigate to **Firestore Database** → **Rules** tab
4. Replace the existing rules with the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection rules
    match /users/{userId} {
      // Allow read and write only if authenticated and accessing own document
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Validation rules (optional but recommended)
      allow create: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.keys().hasAll(['email', 'username', 'preferences', 'createdAt', 'updatedAt'])
                    && request.resource.data.email is string
                    && request.resource.data.username is string;
      
      allow update: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.email == resource.data.email; // Email cannot be changed
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5. Click **Publish** to activate the rules

### Security Rule Explanation:

- **`request.auth != null`**: User must be authenticated
- **`request.auth.uid == userId`**: User can only access their own document
- **Email Protection**: Users cannot change their email (security measure)
- **Field Validation**: Ensures required fields are present on document creation
- **Default Deny**: All other documents/collections are denied by default

## 📦 Code Implementation

### 1. User Profile Model (`lib/models/user_profile_model.dart`)

```dart
class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String? photoUrl;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Methods: fromFirestore, toMap, copyWith
}
```

### 2. Firestore Service (`lib/services/firestore_service.dart`)

**Available Methods:**

| Method | Description | Parameters |
|--------|-------------|------------|
| `createUserDocument()` | Create new user document on signup | uid, email, username, photoUrl |
| `getUserProfile()` | Fetch user profile by UID | uid |
| `getCurrentUserProfile()` | Get logged-in user's profile | - |
| `updateUserProfile()` | Update username, photo, preferences | username, photoUrl, preferences |
| `updatePreference()` | Update single preference | key, value |
| `streamUserProfile()` | Real-time stream of user profile | uid |
| `streamCurrentUserProfile()` | Stream current user's profile | - |
| `deleteUserDocument()` | Delete user document | uid |
| `userDocumentExists()` | Check if user document exists | uid |

**Default Preferences:**
```dart
{
  'theme': 'light',
  'notifications': true,
  'language': 'en'
}
```

### 3. Authentication Flow

**Sign Up:**
```
1. User fills sign-up form
2. Firebase Auth creates account
3. Firestore creates user document with default preferences
4. Local auth backup (for offline)
5. User logged in → Navigate to Home
```

**Login:**
```
1. User enters email/password
2. Firebase Auth authenticates
3. Firestore fetches user profile
4. AuthProvider updates state with profile data
5. User logged in → Navigate to Home
```

**Settings Screen:**
```
1. StreamBuilder listens to user profile changes
2. Displays real-time username, email, preferences
3. User toggles notifications → Firestore updated immediately
4. UI updates automatically via Stream
```

## 🚀 Usage Examples

### Create User on Sign Up
```dart
await _firestoreService.createUserDocument(
  uid: userId,
  email: 'student@university.edu',
  username: 'John Doe',
);
```

### Fetch User Profile
```dart
final profile = await _firestoreService.getCurrentUserProfile();
print('Username: ${profile?.username}');
print('Email: ${profile?.email}');
print('Theme: ${profile?.preferences['theme']}');
```

### Update Notification Preference
```dart
await _firestoreService.updatePreference('notifications', true);
```

### Update Profile Info
```dart
await _firestoreService.updateUserProfile(
  username: 'Jane Smith',
  photoUrl: 'https://example.com/photo.jpg',
);
```

### Real-time Profile Stream
```dart
StreamBuilder<UserProfile?>(
  stream: _firestoreService.streamCurrentUserProfile(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final profile = snapshot.data!;
      return Text('Welcome, ${profile.username}!');
    }
    return CircularProgressIndicator();
  },
)
```

## 🧪 Testing Checklist

### Sign Up Flow
- [ ] Create new account with valid email/password
- [ ] Verify user document created in Firestore
- [ ] Check default preferences are set (theme: light, notifications: true, language: en)
- [ ] Verify createdAt and updatedAt timestamps

### Login Flow
- [ ] Log in with existing credentials
- [ ] Verify user profile loaded from Firestore
- [ ] Check AuthProvider state contains correct username and email
- [ ] Verify navigation to Home screen

### Settings Screen
- [ ] Open Settings screen
- [ ] Verify username and email display correctly
- [ ] Toggle notifications switch
- [ ] Check Firestore document updated immediately
- [ ] Verify profile photo displays (if set)

### Security Testing
- [ ] Try to access another user's document (should fail)
- [ ] Try to modify email field (should fail)
- [ ] Try to access data without authentication (should fail)
- [ ] Verify only authenticated user can read/write own data

## 🔧 Firebase Configuration

Your current Firebase configuration:
```dart
// Firebase Project ID: student-assignment-reminder
// Project Number: 752057448311
// API Key: AIzaSyAaXhNSOTHu8Df26Q_ykLCx6KfmCZ6Khjc
```

**Files to check:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## 📱 Network Issues (Android Emulator)

If you encounter "network error" on Android emulator:

### Workaround 1: Use Physical Device
```bash
# Enable USB debugging on your phone
# Connect via USB
flutter devices
flutter run -d <device-id>
```

### Workaround 2: Use iOS Simulator (macOS only)
```bash
open -a Simulator
flutter run -d <ios-simulator-id>
```

### Workaround 3: Fix Emulator DNS
```bash
# Restart emulator with custom DNS
emulator -avd <avd-name> -dns-server 8.8.8.8
```

### Local Auth Fallback
Your app has local authentication fallback using SharedPreferences that works offline when Firebase fails.

## 📊 Performance Considerations

### Caching
- Firestore automatically caches data locally
- Offline persistence enabled by default
- Data syncs when connection restored

### Best Practices
- Use `streamUserProfile()` for real-time updates only when needed
- Use `getUserProfile()` for one-time reads
- Update preferences individually with `updatePreference()` to minimize writes
- Monitor Firestore usage in Firebase Console (free tier: 50K reads/day, 20K writes/day)

## 🎨 UI/UX Features

### Settings Screen Features
- **Real-time Data Sync**: StreamBuilder updates UI automatically
- **Profile Photo Support**: Displays network image with error fallback
- **Preference Toggles**: Instant Firestore updates
- **Error Handling**: Shows SnackBar on update failures
- **Loading State**: CircularProgressIndicator during data fetch
- **Glassmorphic Design**: Backdrop blur effects for modern look

## 🐛 Troubleshooting

### Issue: "User document not found"
**Solution**: Ensure `createUserDocument()` is called on sign-up

### Issue: "Permission denied"
**Solution**: Check Firestore security rules are published correctly

### Issue: "Network error"
**Solution**: Use physical device or iOS simulator instead of Android emulator

### Issue: Preferences not updating
**Solution**: Verify current user is authenticated (`FirebaseAuth.instance.currentUser != null`)

### Issue: StreamBuilder shows loading forever
**Solution**: Check Firestore rules allow read access and user is authenticated

## 📚 Additional Resources

- [Firebase Authentication Docs](https://firebase.google.com/docs/auth)
- [Cloud Firestore Docs](https://firebase.google.com/docs/firestore)
- [FlutterFire Setup](https://firebase.flutter.dev/docs/overview)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

## 🎯 Next Steps

1. **Add Security Rules** to Firebase Console (see instructions above)
2. **Test Sign-up Flow** on physical device or iOS simulator
3. **Verify Firestore Documents** are created correctly
4. **Test Settings Screen** real-time updates
5. **Add Profile Photo Upload** (future enhancement)
6. **Add Password Reset** functionality (future enhancement)
7. **Add Email Verification** (future enhancement)

---

**Created**: January 2024  
**Last Updated**: January 2024  
**Version**: 1.0.0
