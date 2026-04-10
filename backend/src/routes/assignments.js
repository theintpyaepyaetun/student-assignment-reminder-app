const express = require('express');
const router = express.Router();
const { db } = require('../config/firebase');
const authMiddleware = require('../middleware/auth');

const ALLOWED_PRIORITIES = new Set(['LOW', 'MEDIUM', 'HIGH']);
const ALLOWED_STATUSES = new Set(['PENDING', 'COMPLETED', 'OVERDUE']);

const normalizeText = (value) => String(value || '').trim();

const isIsoDate = (value) => {
  const text = String(value || '').trim();
  if (!text) return false;
  const parsed = new Date(text);
  return !Number.isNaN(parsed.getTime());
};

const normalizePriority = (value) => String(value || '').trim().toUpperCase();
const normalizeStatus = (value) => String(value || '').trim().toUpperCase();

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
    const { title, description, due_date, priority } = req.body || {};
    const normalizedTitle = normalizeText(title);
    const normalizedDescription = normalizeText(description);
    const normalizedPriority = normalizePriority(priority || 'MEDIUM');

    if (!normalizedTitle || !due_date) {
      return res.status(400).json({ error: 'Title and due_date are required' });
    }

    if (normalizedTitle.length > 200) {
      return res.status(400).json({ error: 'Title must be 200 characters or fewer' });
    }

    if (normalizedDescription.length > 2000) {
      return res.status(400).json({ error: 'Description must be 2000 characters or fewer' });
    }

    if (!isIsoDate(due_date)) {
      return res.status(400).json({ error: 'due_date must be a valid date' });
    }

    if (!ALLOWED_PRIORITIES.has(normalizedPriority)) {
      return res.status(400).json({ error: 'priority must be one of LOW, MEDIUM, HIGH' });
    }

    const assignmentRef = db
      .collection('users')
      .doc(userEmail)
      .collection('assignments')
      .doc();

    await assignmentRef.set({
      title: normalizedTitle,
      description: normalizedDescription,
      due_date,
      priority: normalizedPriority,
      status: 'PENDING',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    res.status(201).json({
      id: assignmentRef.id,
      title: normalizedTitle,
      description: normalizedDescription,
      due_date,
      priority: normalizedPriority,
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
    const { title, description, due_date, priority, status } = req.body || {};

    const updates = {};

    if (title !== undefined) {
      const normalizedTitle = normalizeText(title);
      if (!normalizedTitle) {
        return res.status(400).json({ error: 'title cannot be empty' });
      }
      if (normalizedTitle.length > 200) {
        return res.status(400).json({ error: 'Title must be 200 characters or fewer' });
      }
      updates.title = normalizedTitle;
    }

    if (description !== undefined) {
      const normalizedDescription = normalizeText(description);
      if (normalizedDescription.length > 2000) {
        return res.status(400).json({ error: 'Description must be 2000 characters or fewer' });
      }
      updates.description = normalizedDescription;
    }

    if (due_date !== undefined) {
      if (!isIsoDate(due_date)) {
        return res.status(400).json({ error: 'due_date must be a valid date' });
      }
      updates.due_date = due_date;
    }

    if (priority !== undefined) {
      const normalizedPriority = normalizePriority(priority);
      if (!ALLOWED_PRIORITIES.has(normalizedPriority)) {
        return res.status(400).json({ error: 'priority must be one of LOW, MEDIUM, HIGH' });
      }
      updates.priority = normalizedPriority;
    }

    if (status !== undefined) {
      const normalizedStatus = normalizeStatus(status);
      if (!ALLOWED_STATUSES.has(normalizedStatus)) {
        return res.status(400).json({ error: 'status must be one of PENDING, COMPLETED, OVERDUE' });
      }
      updates.status = normalizedStatus;
    }

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
