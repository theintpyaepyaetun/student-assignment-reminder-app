# Student Assignment Reminder - Backend API

Node.js/Express backend for the Student Assignment Reminder App using Firebase Firestore.

## Features

- ✅ User authentication with JWT and Firebase Firestore
- ✅ Assignment CRUD operations
- ✅ User profile management
- ✅ Firebase Firestore database
- ✅ CORS support
- ✅ Password hashing with bcryptjs

## Project Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── firebase.js      # Firebase Admin SDK initialization
│   │   └── auth.js          # JWT token generation/verification
│   ├── middleware/
│   │   └── auth.js          # Authentication middleware
│   ├── routes/
│   │   ├── auth.js          # Login/Register endpoints
│   │   ├── assignments.js   # Assignment CRUD endpoints
│   │   └── user.js          # User profile endpoints
│   └── index.js             # Main server file
├── package.json
├── .env.example
└── README.md
```

## Installation

### Prerequisites

1. Node.js (v14+)
2. Firebase project with Firestore database enabled

### Setup Steps

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Set up Firebase:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use existing one
   - Go to Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file

4. Create a `.env` file from `.env.example`:
```bash
cp .env.example .env
```

5. Update `.env` with your Firebase service account credentials:
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_CLIENT_ID=your-client-id
FIREBASE_CLIENT_X509_CERT_URL=your-cert-url
```

6. Ensure Firestore Database is created in Firebase Console

## Running the Server

### Development mode (with auto-reload):
```bash
npm run dev
```

### Production mode:
```bash
npm start
```

The server will run on `http://localhost:5000` by default.

## Firestore Database Structure

### Collections

```
users/
  └── {email}/
      ├── email: string
      ├── name: string
      ├── password: string (hashed)
      ├── created_at: timestamp
      ├── updated_at: timestamp
      └── assignments/
          └── {assignmentId}/
              ├── title: string
              ├── description: string
              ├── due_date: date
              ├── priority: string (LOW, MEDIUM, HIGH)
              ├── status: string (PENDING, COMPLETED, OVERDUE)
              ├── created_at: timestamp
              └── updated_at: timestamp
```

## API Endpoints

### Authentication

#### Register
```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

#### Login
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### Assignments

#### Get All Assignments
```bash
GET /api/assignments
Authorization: Bearer <token>
```

#### Get Single Assignment
```bash
GET /api/assignments/{id}
Authorization: Bearer <token>
```

#### Create Assignment
```bash
POST /api/assignments
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Math Homework",
  "description": "Chapter 5, Problems 1-50",
  "due_date": "2026-02-28",
  "priority": "HIGH"
}
```

#### Update Assignment
```bash
PUT /api/assignments/{id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "status": "COMPLETED",
  "priority": "MEDIUM"
}
```

#### Delete Assignment
```bash
DELETE /api/assignments/{id}
Authorization: Bearer <token>
```

### User Profile

#### Get Profile
```bash
GET /api/user/profile
Authorization: Bearer <token>
```

### Health Check

```bash
GET /api/health
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NODE_ENV` | Environment mode (development/production) |
| `PORT` | Server port (default: 5000) |
| `JWT_SECRET` | Secret key for JWT tokens |
| `CORS_ORIGIN` | CORS allowed origin |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_PRIVATE_KEY_ID` | Firebase private key ID |
| `FIREBASE_PRIVATE_KEY` | Firebase private key |
| `FIREBASE_CLIENT_EMAIL` | Firebase client email |
| `FIREBASE_CLIENT_ID` | Firebase client ID |
| `FIREBASE_CLIENT_X509_CERT_URL` | Firebase certificate URL |

## Dependencies

- **express** - Web framework
- **firebase-admin** - Firebase Admin SDK
- **bcryptjs** - Password hashing
- **jsonwebtoken** - JWT authentication
- **dotenv** - Environment variables
- **cors** - CORS middleware
- **body-parser** - Request parsing

## Dev Dependencies

- **nodemon** - Auto-reload during development
- **jest** - Testing framework

## Error Handling

The API returns standard HTTP status codes:

- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `500` - Server Error

## License

MIT
