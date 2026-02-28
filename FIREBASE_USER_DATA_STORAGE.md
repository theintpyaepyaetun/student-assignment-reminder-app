# 🔥 Firebase User Data Storage Implementation

## Overview
Your app uses **two Firebase services** for user data storage:

1. **Firestore** (Cloud Firestore) - For tasks with advanced querying
2. **Realtime Database** - For assignments with real-time synchronization

---

## Current Setup ✅

### 1. Authentication (Firebase Auth)
- Email/Password authentication configured
- Current user accessible via `FirebaseAuth.instance.currentUser?.uid`
- Each document/record is linked to user via `userId` field

### 2. Data Storage Architecture

```
Firebase Project (student-assignment-reminder)
│
├── Firestore Database
│   ├── Collection: tasks
│   │   └── Document Structure:
│   │       {
│   │         userId: "auth_uid",
│   │         title: String,
│   │         description: String,
│   │         dueDate: DateTime,
│   │         isCompleted: Boolean,
│   │         category: String,
│   │         priority: Integer,
│   │         createdAt: Timestamp,
│   │         updatedAt: Timestamp
│   │       }
│   │
│   └── Collection: notes
│       └── Document Structure:
│           {
│             userId: "auth_uid",
│             title: String,
│             content: String,
│             createdAt: Timestamp,
│             updatedAt: Timestamp
│           }
│
└── Realtime Database
    └── Structure: users/{userId}/assignments/{assignmentId}
        {
          title: String,
          description: String,
          dueDate: String,
          priority: String,
          status: String,
          completed: Boolean,
          createdAt: String
        }
```

---

## Service Structure

### TaskService (`lib/services/task_service.dart`)

**CREATE Operations:**
```dart
✅ createTask() 
   - Auto-adds userId from Firebase Auth
   - Uses server timestamps
   - Returns task ID

Example:
  final taskId = await _taskService.createTask(
    title: 'Buy groceries',
    description: 'Milk, eggs, bread',
    dueDate: DateTime.now().add(Duration(days: 7)),
    category: 'Shopping',
    priority: 2,
  );
```

**READ Operations:**
```dart
✅ getAllTasks() - Get all user's tasks
✅ getTaskById() - Get single task with permission check
✅ getTasksByCategory() - Filter by category
✅ getIncompleteTasks() - Get pending tasks
✅ getCompletedTasks() - Get completed tasks
✅ getHighPriorityTasks() - Filter by priority
✅ getTaskStats() - Get statistics
✅ streamAllTasks() - Real-time stream of tasks
```

**UPDATE Operations:**
```dart
✅ updateTask() - Update any field
✅ completeTask() - Mark as complete
✅ incompleteTask() - Mark as incomplete
```

**DELETE Operations:**
```dart
✅ deleteTask() - Delete single task with ownership check
✅ deleteCompletedTasks() - Delete all completed
```

### AssignmentService (via FirebaseService)

**Methods:**
```dart
✅ addAssignment() - Create new assignment
✅ getAssignments() - Get user's assignments
✅ updateAssignment() - Update assignment
✅ deleteAssignment() - Delete assignment
✅ getAssignmentsStream() - Real-time stream
```

---

## How Data is Stored

### When User Creates a Task:

**Step 1: User fills form**
```dart
// In add_assignment_screen.dart
final title = titleController.text;
final description = descriptionController.text;
final dueDate = selectedDate;
```

**Step 2: Provider saves to Firestore**
```dart
// In TaskProvider.createTask()
final taskId = await _taskService.createTask(
  title: title,
  description: description,
  dueDate: dueDate,
);
```

**Step 3: TaskService adds userId automatically**
```dart
// In TaskService.createTask()
final userId = currentUserId; // From FirebaseAuth
await _firestore.collection('tasks').add({
  'userId': userId,        // ⭐ Auto-added
  'title': title,
  'description': description,
  'dueDate': dueDate,
  'isCompleted': false,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Step 4: Data appears in Firestore**
```
Firestore Console:
  Database → Collections → tasks
    └── Document (auto-generated ID)
        ├── userId: "abc123xyz"
        ├── title: "Buy groceries"
        ├── description: "Milk, eggs, bread"
        ├── dueDate: 2026-03-07
        ├── isCompleted: false
        ├── createdAt: Mar 1, 2026 10:30:00 AM
        └── updatedAt: Mar 1, 2026 10:30:00 AM
```

### When User Creates an Assignment:

**Step 1: User fills form**
```dart
// In add_assignment_screen.dart
final assignment = {
  'title': titleController.text,
  'description': descriptionController.text,
  'dueDate': dueDateController.text,
  'priority': selectedPriority,
};
```

**Step 2: Provider saves to Realtime Database**
```dart
// In AssignmentProvider.createAssignment()
await _firebaseService.addAssignment(userId, assignment);
```

**Step 3: FirebaseService saves with userId**
```dart
// In FirebaseService.addAssignment()
final userId = _auth.currentUser?.uid;
await _database
    .ref('users/$userId/assignments')
    .push()
    .set(assignment);
```

**Step 4: Data appears in Realtime Database**
```
Firebase Realtime Database:
  users/
    └── abc123xyz/
        └── assignments/
            ├── -abc123/
            │   ├── title: "Math Homework"
            │   ├── description: "..."
            │   ├── dueDate: "Feb 25"
            │   ├── priority: "high"
            │   └── completed: false
            │
            └── -def456/
                ├── title: "English Essay"
                ├── description: "..."
                ├── dueDate: "Mar 1"
                ├── priority: "medium"
                └── completed: true
```

---

## Multi-User Data Isolation

### User A (uid: alice123)
```
Firestore - tasks collection:
  ├── task_id_1: { userId: 'alice123', title: 'Buy milk', ... }
  ├── task_id_2: { userId: 'alice123', title: 'Study Math', ... }

Realtime DB:
  users/alice123/assignments/
    ├── -a1: { title: 'History Essay', ... }
    └── -a2: { title: 'Biology Lab', ... }
```

### User B (uid: bob456)
```
Firestore - tasks collection:
  ├── task_id_3: { userId: 'bob456', title: 'Pay bills', ... }
  ├── task_id_4: { userId: 'bob456', title: 'Call mom', ... }

Realtime DB:
  users/bob456/assignments/
    ├── -b1: { title: 'Chemistry Test', ... }
    └── -b2: { title: 'Art Project', ... }
```

**Result:** User A can only see their tasks/assignments, User B can only see theirs.

---

## Firestore Security Rules

Add these to your Firebase Console for production security:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Tasks collection - user can only access their own tasks
    match /tasks/{document=**} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                              resource.data.userId == request.auth.uid;
    }
    
    // Notes collection - user can only access their own notes
    match /notes/{document=**} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && 
                              resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## Realtime Database Security Rules

Add these to your Firebase Console:

```javascript
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "assignments": {
          "$assignmentId": {
            ".validate": "newData.hasChildren(['title', 'dueDate'])"
          }
        }
      }
    }
  }
}
```

---

## Current Implementation Status

### ✅ Complete
- [x] Firebase Auth integration
- [x] TaskService with CRUD operations
- [x] TaskProvider state management
- [x] AssignmentProvider with Realtime DB
- [x] Auto userId assignment on create
- [x] Permission checks on read/update/delete
- [x] Real-time streaming

### 🔄 In Progress
- [ ] Deploy Firestore Security Rules
- [ ] Deploy Realtime DB Security Rules
- [ ] Test multi-user scenarios
- [ ] Data persistence verification

### 📝 To Implement (Optional)
- [ ] Cloud Functions for data validation
- [ ] Backup/export functionality
- [ ] Data migration tools
- [ ] Analytics tracking

---

## Testing Checklist

### ✓ Single User Flow
```
1. Create account
2. Add task
3. Check Firestore Console - task appears with userId
4. Refresh app - task still there
5. Update task
6. Delete task
```

### ✓ Multi-User Flow
```
1. Create account (User A)
2. Add several tasks
3. Logout
4. Create second account (User B)
5. Add tasks
6. Verify User B cannot see User A's tasks
7. Switch back to User A
8. Verify User A still sees their tasks only
```

### ✓ Data Persistence
```
1. Create account
2. Add tasks
3. Force stop app
4. Reopen app
5. Login
6. Verify tasks still appear
```

---

## Code Examples

### Example 1: Create Task from UI
```dart
// In add_assignment_screen.dart
onPressed: () async {
  final taskId = await context.read<TaskProvider>().createTask(
    title: titleController.text,
    description: descriptionController.text,
    dueDate: selectedDate,
    category: categoryController.text,
    priority: int.tryParse(priorityController.text),
  );
  
  if (taskId != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created successfully')),
    );
    Navigator.pop(context);
  }
}
```

### Example 2: Display Tasks in Real-Time
```dart
// In home_screen.dart
Consumer<TaskProvider>(
  builder: (context, taskProvider, _) {
    if (taskProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (taskProvider.allTasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }
    
    return ListView.builder(
      itemCount: taskProvider.allTasks.length,
      itemBuilder: (context, index) {
        final task = taskProvider.allTasks[index];
        return ListTile(
          title: Text(task.title),
          subtitle: Text(task.description),
          trailing: Checkbox(
            value: task.isCompleted,
            onChanged: (_) {
              context.read<TaskProvider>().completeTask(task.id);
            },
          ),
        );
      },
    );
  },
)
```

### Example 3: Update Task
```dart
// Update task completion status
Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
  try {
    if (isCompleted) {
      await _taskService.completeTask(taskId);
    } else {
      await _taskService.incompleteTask(taskId);
    }
  } catch (e) {
    print('Error updating task: $e');
  }
}
```

### Example 4: Delete Task
```dart
// Delete task with confirmation
Future<void> deleteTaskWithConfirmation(String taskId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Task?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  
  if (confirm == true) {
    await context.read<TaskProvider>().deleteTask(taskId);
  }
}
```

---

## Deployment Steps

### 1. Deploy Security Rules

**Firestore:**
1. Go to Firebase Console → Your Project
2. Firestore Database → Rules tab
3. Copy the rules from above
4. Click Publish

**Realtime Database:**
1. Go to Firebase Console → Your Project
2. Realtime Database → Rules tab
3. Copy the rules from above
4. Click Publish

### 2. Test in Firebase Console

**Firestore:**
1. Collections → tasks
2. Create test documents with userId field
3. Try reading as different users

**Realtime Database:**
1. Data tab
2. Navigate to users/{userId}/assignments
3. Add test data
4. Verify structure

### 3. Test in App

1. Run `flutter run`
2. Create account
3. Add task/assignment
4. Check Firebase Console → Data appears
5. Logout and login
6. Verify data persists

---

## Troubleshooting

### Problem: Data not saving
**Solution:**
- Check Firebase Auth is initialized
- Verify user is authenticated (check `FirebaseAuth.instance.currentUser`)
- Check Firebase Console rules don't block writes
- Check console for errors: `adb logcat | grep firebase`

### Problem: Can see other users' data
**Solution:**
- Deploy Firestore Security Rules
- Deploy Realtime DB Security Rules
- Verify `userId` field is set in queries
- Check rules in Firebase Console

### Problem: Data disappears after logout
**Solution:**
- Data should be in Firebase (not local cache)
- Logout/login should retrieve from Firestore
- Check network connection
- Check Firebase Console data exists

---

## Summary

Your app now has:
✅ User authentication via Firebase Auth
✅ Tasks stored in Firestore with userId
✅ Assignments stored in Realtime DB with userId
✅ Real-time data synchronization
✅ Multi-user data isolation via userId
✅ CRUD operations for both collections

All data is automatically linked to the current user and stored in Firebase!
