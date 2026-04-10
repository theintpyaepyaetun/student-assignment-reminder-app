const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { db } = require('../config/firebase');
const { generateToken } = require('../config/auth');
const { authRateLimit } = require('../middleware/rateLimit');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const normalizeEmail = (value) => String(value || '').trim().toLowerCase();

const isValidEmail = (value) => EMAIL_REGEX.test(normalizeEmail(value));

const isStrongEnoughPassword = (value) => {
  const password = String(value || '');
  return password.length >= 8;
};

const validateName = (value) => {
  const name = String(value || '').trim();
  if (!name) return null;
  if (name.length > 80) return null;
  return name;
};

// Register
router.post('/register', authRateLimit, async (req, res) => {
  try {
    const { email, password, name } = req.body || {};
    const normalizedEmail = normalizeEmail(email);
    const normalizedName = validateName(name);

    if (!normalizedEmail || !password || !normalizedName) {
      return res.status(400).json({ error: 'Email, password, and name are required' });
    }

    if (!isValidEmail(normalizedEmail)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    if (!isStrongEnoughPassword(password)) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    // Check if user already exists
    const userRef = db.collection('users').doc(normalizedEmail);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      return res.status(400).json({ error: 'Email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user document
    await userRef.set({
      email: normalizedEmail,
      password: hashedPassword,
      name: normalizedName,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    const token = generateToken(normalizedEmail, normalizedEmail);

    res.status(201).json({
      message: 'User registered successfully',
      email: normalizedEmail,
      token
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Login
router.post('/login', authRateLimit, async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const normalizedEmail = normalizeEmail(email);

    if (!normalizedEmail || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    if (!isValidEmail(normalizedEmail)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    const userRef = db.collection('users').doc(normalizedEmail);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = userDoc.data();
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = generateToken(normalizedEmail, normalizedEmail);

    res.json({
      message: 'Login successful',
      email: user.email,
      name: user.name,
      token
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
