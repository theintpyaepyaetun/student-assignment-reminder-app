const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { db } = require('../config/firebase');
const { generateToken } = require('../config/auth');

// Register
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;

    if (!email || !password || !name) {
      return res.status(400).json({ error: 'Email, password, and name are required' });
    }

    // Check if user already exists
    const userRef = db.collection('users').doc(email);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      return res.status(400).json({ error: 'Email already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user document
    await userRef.set({
      email,
      password: hashedPassword,
      name,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    const token = generateToken(email, email);

    res.status(201).json({
      message: 'User registered successfully',
      email,
      token
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const userRef = db.collection('users').doc(email);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = userDoc.data();
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = generateToken(email, email);

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
