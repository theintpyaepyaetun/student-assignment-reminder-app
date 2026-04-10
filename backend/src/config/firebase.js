const admin = require('firebase-admin');
const fs = require('fs');
require('dotenv').config();

const normalizePrivateKey = (rawKey) => {
  if (!rawKey) return rawKey;
  let normalized = String(rawKey).trim();

  if (
    (normalized.startsWith('"') && normalized.endsWith('"')) ||
    (normalized.startsWith("'") && normalized.endsWith("'"))
  ) {
    normalized = normalized.slice(1, -1);
  }

  return normalized.replace(/\\n/g, '\n');
};

const loadServiceAccount = () => {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (serviceAccountPath) {
    const raw = fs.readFileSync(serviceAccountPath, 'utf8');
    return JSON.parse(raw);
  }

  return {
    type: process.env.FIREBASE_TYPE || 'service_account',
    project_id: process.env.FIREBASE_PROJECT_ID,
    private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
    private_key: normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY),
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
    client_id: process.env.FIREBASE_CLIENT_ID,
    auth_uri:
      process.env.FIREBASE_AUTH_URI ||
      'https://accounts.google.com/o/oauth2/auth',
    token_uri:
      process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
    auth_provider_x509_cert_url:
      process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL ||
      'https://www.googleapis.com/oauth2/v1/certs',
    client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
  };
};

// Initialize Firebase Admin SDK
const serviceAccount = loadServiceAccount();

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Set Firestore settings
db.settings({
  ignoreUndefinedProperties: true
});

console.log('Firebase Firestore initialized successfully');

module.exports = {
  db,
  admin,
  auth: admin.auth()
};
