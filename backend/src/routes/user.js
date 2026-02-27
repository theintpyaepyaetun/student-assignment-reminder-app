const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');
const authMiddleware = require('../middleware/auth');

// Get user profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;
    const userDoc = await db.collection('users').doc(userEmail).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userData = userDoc.data();
    res.json({
      email: userData.email,
      name: userData.name,
      created_at: userData.created_at
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
