const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');
const authMiddleware = require('../middleware/auth');

// Get all assignments for user
router.get('/', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;
    const snapshot = await db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .orderBy('due_date', 'asc')
      .get();

    const assignments = [];
    snapshot.forEach((doc) => {
      assignments.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.json(assignments);
  } catch (error) {
    console.error('Get assignments error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single assignment
router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;
    const doc = await db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .doc(req.params.id)
      .get();

    if (!doc.exists) {
      return res.status(404).json({ error: 'Assignment not found' });
    }

    res.json({
      id: doc.id,
      ...doc.data()
    });
  } catch (error) {
    console.error('Get assignment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create assignment
router.post('/', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;
    const { title, description, due_date, priority } = req.body;

    if (!title || !due_date) {
      return res.status(400).json({ error: 'Title and due_date are required' });
    }

    const assignmentRef = db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .doc();

    await assignmentRef.set({
      title,
      description: description || '',
      due_date,
      priority: priority || 'MEDIUM',
      status: 'PENDING',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    res.status(201).json({
      id: assignmentRef.id,
      title,
      description,
      due_date,
      priority: priority || 'MEDIUM',
      status: 'PENDING',
      created_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Create assignment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update assignment
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;
    const { title, description, due_date, priority, status } = req.body;

    const updates = {};

    if (title !== undefined) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (due_date !== undefined) updates.due_date = due_date;
    if (priority !== undefined) updates.priority = priority;
    if (status !== undefined) updates.status = status;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    updates.updated_at = new Date().toISOString();

    await db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .doc(req.params.id)
      .update(updates);

    res.json({ message: 'Assignment updated successfully' });
  } catch (error) {
    if (error.code === 'not-found') {
      return res.status(404).json({ error: 'Assignment not found' });
    }
    console.error('Update assignment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete assignment
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const userEmail = req.userEmail;

    await db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .doc(req.params.id)
      .delete();

    res.json({ message: 'Assignment deleted successfully' });
  } catch (error) {
    console.error('Delete assignment error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
