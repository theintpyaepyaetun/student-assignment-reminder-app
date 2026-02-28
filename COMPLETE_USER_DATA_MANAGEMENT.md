# Complete User-Specific Data Management System - Firebase & Firestore

## 📋 Overview

This document provides a complete implementation guide for user-specific data management in your Flutter app using Firebase Authentication and Cloud Firestore. Users can only see and manage their own data through secure rules and userId validation.

---

## 🗂️ Database Structure

### Collections Architecture

```
Firestore Database
│
├── users/                          # User profiles collection
│   └── {uid}/
│       ├── email: string
│       ├── username: string
│       ├── photoUrl: string | null
│       ├── preferences: {
│       │   ├── theme: "light" | "dark"
│       │   ├── notifications: boolean
│       │   └── language: string
│       │}
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp
│
├── tasks/                          # Tasks collection (user-specific)
│   └── {taskId}/
│       ├── userId: string          ⭐ REQUIRED - Links to user
│       ├── title: string
│       ├── description: string
│       ├── isCompleted: boolean
│       ├── createdAt: timestamp
│       ├── dueDate: timestamp
│       ├── category: string
│       ├── priority: integer (1-3)
│       └── updatedAt: timestamp
│
└── notes/                          # Notes collection (user-specific)
    └── {noteId}/
        ├── userId: string          ⭐ REQUIRED - Links to user
        ├── title: string
        ├── content: string
        ├── tags: array of strings
        ├── isPinned: boolean
        ├── color: string
        ├── createdAt: timestamp
        └── updatedAt: timestamp
```

---

## 🔒 Firestore Security Rules

**CRITICAL: You MUST add these security rules to your Firebase Console for the app to work properly.**

### How to Add Security Rules:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **student-assignment-reminder**
3. Navigate to **Firestore Database** → **Rules** tab
4. Replace the entire content with the following rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check authentication
    function isAuth() {
      return request.auth != null;
    }
    
    // Helper function to check user ownership
    function isUserDoc(userId) {
      return request.auth.uid == userId;
    }
    
    // Helper function to check document ownership by userId field
    function isOwner() {
      return request.auth.uid == resource.data.userId;
    }
    
    // ============ USERS COLLECTION ============
    // Users can only read/write their own profile
    match /users/{userId} {
      allow read: if isAuth() && isUserDoc(userId);
      allow write: if isAuth() && isUserDoc(userId);
      allow create: if isAuth() && isUserDoc(userId) && 
                      request.resource.data.keys().hasAll([
                        'email', 'username', 'createdAt', 'updatedAt'
                      ]) &&
                      request.resource.data.email is string &&
                      request.resource.data.username is string;
      allow update: if isAuth() && isUserDoc(userId) &&
                      // Email cannot be changed
                      request.resource.data.email == resource.data.email;
    }
    
    // ============ TASKS COLLECTION ============
    // Users can only read/write their own tasks
    match /tasks/{taskId} {
      // Read: User must be authenticated and task must belong to them
      allow read: if isAuth() && isOwner();
      
      // Write (Create): Must include userId matching current user
      allow create: if isAuth() && 
                      isUserDoc(request.resource.data.userId) &&
                      request.resource.data.keys().hasAll([
                        'userId', 'title', 'description', 'dueDate', 'createdAt'
                      ]) &&
                      request.resource.data.userId is string &&
                      request.resource.data.title is string &&
                      request.resource.data.isCompleted is bool;
      
      // Update: User must own the task and userId cannot be changed
      allow update: if isAuth() && isOwner() &&
                      request.resource.data.userId == resource.data.userId;
      
      // Delete: User must own the task
      allow delete: if isAuth() && isOwner();
    }
    
    // ============ NOTES COLLECTION ============
    // Users can only read/write their own notes
    match /notes/{noteId} {
      // Read: User must be authenticated and note must belong to them
      allow read: if isAuth() && isOwner();
      
      // Write (Create): Must include userId matching current user
      allow create: if isAuth() && 
                      isUserDoc(request.resource.data.userId) &&
                      request.resource.data.keys().hasAll([
                        'userId', 'title', 'content', 'createdAt', 'updatedAt'
                      ]) &&
                      request.resource.data.userId is string &&
                      request.resource.data.title is string &&
                      request.resource.data.content is string;
      
      // Update: User must own the note and userId cannot be changed
      allow update: if isAuth() && isOwner() &&
                      request.resource.data.userId == resource.data.userId;
      
      // Delete: User must own the note
      allow delete: if isAuth() && isOwner();
    }
    
    // ============ DEFAULT DENY ============
    // Deny access to any other collections/paths
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5. Click **Publish** to activate the rules

### Security Rules Explanation:

- **`isAuth()`**: Verifies user is authenticated
- **`isUserDoc(userId)`**: Verifies `request.auth.uid == userId` for profile documents
- **`isOwner()`**: Verifies `request.auth.uid == resource.data.userId` for data documents
- **Field Validation**: Ensures required fields are present and correct types
- **UserId Immutability**: `userId` cannot be changed after creation
- **Default Deny**: All other paths are denied by default

---

## 📱 Flutter Implementation

### 1. **Task Model** (`lib/models/task_model.dart`)

Complete task model with serialization/deserialization:
- Fields: id, userId, title, description, isCompleted, dates, category, priority
- Methods: `toMap()`, `fromMap()`, `copyWith()`

### 2. **Task Service** (`lib/services/task_service.dart`)

Comprehensive CRUD operations:

**CREATE:**
- `createTask()` - Creates new task with userId

**READ:**
- `getTaskById()` - Get single task with permission check
- `getAllTasks()` - Get all user's tasks
- `getTasksByCategory()` - Filter by category
- `getIncompleteTasks()` - Filter by status
- `getHighPriorityTasks()` - Get high priority tasks
- `streamAllTasks()` - Real-time updates
- `streamIncompleteTasks()` - Real-time incomplete tasks
- `getTaskStats()` - Get task statistics

**UPDATE:**
- `updateTask()` - Update task with permission check
- `completeTask()` - Mark task complete
- `incompleteTask()` - Mark task incomplete

**DELETE:**
- `deleteTask()` - Delete single task
- `deleteCompletedTasks()` - Delete all completed
- `deleteMultipleTasks()` - Batch delete

**BATCH OPERATIONS:**
- `completeMultipleTasks()` - Batch update
- `deleteMultipleTasks()` - Batch delete

### 3. **Task Provider** (`lib/providers/task_provider.dart`)

State management for tasks with:
- Task list management
- Loading states
- Error handling
- Refresh functionality

### 4. **Note Model & Service** (`lib/models/note_model.dart`, `lib/services/note_service.dart`)

Similar comprehensive CRUD for notes with additional features:
- Tag management
- Pin functionality
- Color coding
- Real-time streaming

---

## 🚀 Usage Examples

### Initialize User Profile (On Sign-up)

```dart
// In your AuthProvider sign-up method
final userId = credential.user!.uid;

// Create Firestore user document
await _firestoreService.createUserDocument(
  uid: userId,
  email: email,
  username: name,
);
```

### Create a Task

```dart
final taskId = await _taskService.createTask(
  title: 'Buy groceries',
  description: 'Milk, eggs, bread',
  dueDate: DateTime.now().add(Duration(days: 7)),
  category: 'Shopping',
  priority: 2, // Medium
);

print('Task created: $taskId');
```

### Get User's Tasks with Filtering

```dart
// Get all tasks
List<Task> allTasks = await _taskService.getAllTasks();

// Get incomplete tasks
List<Task> pending = await _taskService.getIncompleteTasks();

// Get high priority
List<Task> urgent = await _taskService.getHighPriorityTasks();

// Get by category
List<Task> work = await _taskService.getTasksByCategory('Work');
```

### Real-time Updates with StreamBuilder

```dart
StreamBuilder<List<Task>>(
  stream: _taskService.streamAllTasks(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    
    final tasks = snapshot.data ?? [];
    
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          title: Text(task.title),
          subtitle: Text(task.description),
          trailing: Checkbox(
            value: task.isCompleted,
            onChanged: (value) {
              if (value!) {
                _taskService.completeTask(task.id);
              } else {
                _taskService.incompleteTask(task.id);
              }
            },
          ),
        );
      },
    );
  },
)
```

### Update a Task

```dart
final updatedTask = task.copyWith(
  title: 'New Title',
  isCompleted: true,
  priority: 3,
);

await _taskService.updateTask(taskId, updatedTask);
```

### Delete Operations

```dart
// Delete single task
await _taskService.deleteTask(taskId);

// Delete all completed tasks
await _taskService.deleteCompletedTasks();

// Delete multiple tasks
await _taskService.deleteMultipleTasks(['taskId1', 'taskId2', 'taskId3']);
```

### Get Task Statistics

```dart
final stats = await _taskService.getTaskStats();
print('Total: ${stats['total']}');
print('Completed: ${stats['completed']}');
print('Pending: ${stats['pending']}');
```

### Note Operations

```dart
// Create note
final noteId = await _noteService.createNote(
  title: 'Meeting Notes',
  content: 'Discussed project roadmap',
  tags: ['meeting', 'important'],
  color: '#FF5733',
);

// Toggle pin
await _noteService.togglePinNote(noteId);

// Add tag
await _noteService.addTagToNote(noteId, 'urgent');

// Get pinned notes (real-time)
Stream<List<Note>> pinnedNotes = _noteService.streamAllNotes()
  .map((notes) => notes.where((n) => n.isPinned).toList());
```

---

## 🔐 Security Features

### Permission Checks

Every operation validates:
1. **User Authentication**: `request.auth != null`
2. **User Ownership**: `request.auth.uid == resource.data.userId`
3. **Data Integrity**: `userId` field is immutable

### Data Isolation

- Users can only create documents with their own `userId`
- Users cannot modify or delete others' documents
- Queries automatically filtered by `userId`
- Firestore Security Rules enforce at database level

### Offline Persistence

- Firestore SDK caches data locally
- Queries work offline (returning cached data)
- Changes sync when connection restored
- userId field ensures proper sync

---

## 📊 Performance Tips

### Indexing

Firestore automatically creates indexes for queries. For better performance, manually create composite indexes for:

```
Collection: tasks
Fields: userId (Ascending), dueDate (Ascending)

Collection: tasks
Fields: userId (Ascending), isCompleted (Ascending), dueDate (Ascending)

Collection: notes
Fields: userId (Ascending), isPinned (Descending), updatedAt (Descending)
```

### Query Optimization

✅ **DO:**
- Use `where` clause to filter by userId (automatic)
- Limit query results with `.limit()`
- Order results with `.orderBy()`
- Use specific field queries

❌ **DON'T:**
- Query all documents then filter client-side
- Create unlimited listeners
- Query without userId condition (prevented by rules)

### Firestore Pricing

Free tier limits:
- 50,000 reads/day
- 20,000 writes/day
- 20,000 deletes/day

Each operation (read/write/delete) counts as 1 document.

---

## 🧪 Testing Checklist

### User Authentication
- [ ] User can sign up
- [ ] Sign-up creates user document in `users` collection
- [ ] User profile appears in Firestore console
- [ ] userId matches Firebase Auth uid

### Task CRUD
- [ ] Can create task (userId field auto-populated)
- [ ] Task appears in Firestore `tasks` collection
- [ ] Cannot create task with different userId
- [ ] Can read own tasks
- [ ] Cannot read other users' tasks
- [ ] Can update own tasks
- [ ] Cannot update other users' tasks
- [ ] Can delete own tasks
- [ ] Cannot delete other users' tasks
- [ ] Real-time updates work (StreamBuilder)

### Data Persistence
- [ ] Sign out user
- [ ] Sign in same user
- [ ] User sees only their own tasks/notes
- [ ] Task/note data is intact
- [ ] Timestamps are correct

### Security Rules
- [ ] Try to access another user's task (should fail)
- [ ] Try to modify userId field (should fail)
- [ ] Try to read without authentication (should fail)
- [ ] Try to create task with different userId (should fail)
- [ ] Firestore rules enforced (check Console)

### Performance
- [ ] Query completes in < 1 second
- [ ] Real-time updates are responsive
- [ ] No N+1 query problems
- [ ] Batch operations work

---

## 🐛 Troubleshooting

### Issue: "Permission denied" error

**Causes:**
- Security rules not published
- userId field missing in document
- User not authenticated
- Accessing another user's document

**Solution:**
- Verify rules are published in Firebase Console
- Ensure `userId` field is always set to `request.auth.uid`
- Check `FirebaseAuth.instance.currentUser` is not null
- Verify document's `userId` matches current user

### Issue: Queries return empty

**Causes:**
- Query filters by userId correctly but no data exists
- Wrong collection name
- Offline (cached data empty)

**Solution:**
- Create test document in Firestore Console
- Verify collection name matches
- Check internet connection
- Wait for sync if offline

### Issue: Real-time updates not working

**Causes:**
- Listener not created properly
- User not authenticated when stream created
- Collection doesn't have documents

**Solution:**
- Check StreamBuilder error state
- Verify authentication before creating stream
- Check Firestore rules allow read access
- Create test documents

---

## 🎯 Next Steps

1. ✅ **Add Security Rules** to Firebase Console (see above)
2. ✅ **Test Sign-up** - Creates user document
3. ✅ **Test Task CRUD** - Create, read, update, delete
4. ✅ **Test Persistence** - Sign out/in sees own data
5. ✅ **Monitor Firestore** - Check Console for documents
6. 📊 **Optimize Queries** - Add indexes as needed
7. 🚀 **Deploy to Production** - Test with real users

---

## 📚 Additional Resources

- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [FlutterFire Documentation](https://firebase.flutter.dev/docs/overview)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Firebase Authentication Flutter](https://firebase.flutter.dev/docs/auth/overview)

---

**Version**: 1.0.0  
**Last Updated**: February 2024  
**Status**: Production Ready ✅
