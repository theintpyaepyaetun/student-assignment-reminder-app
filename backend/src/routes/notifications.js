const express = require('express');
const router = express.Router();
const { db, admin } = require('../config/firebase');
const authMiddleware = require('../middleware/auth');

const stringifyData = (data) => {
  if (!data || typeof data !== 'object') return {};

  const result = {};
  for (const [key, value] of Object.entries(data)) {
    result[key] = value == null ? '' : String(value);
  }
  return result;
};

const parseDeadline = (rawDeadline) => {
  if (!rawDeadline) return null;

  if (typeof rawDeadline === 'number') {
    const fromEpoch = new Date(rawDeadline);
    return Number.isNaN(fromEpoch.getTime()) ? null : fromEpoch;
  }

  const parsed = new Date(String(rawDeadline));
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const isDueTomorrowLocal = (deadlineDate, now = new Date()) => {
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const tomorrowStart = new Date(todayStart);
  tomorrowStart.setDate(tomorrowStart.getDate() + 1);

  const dayAfterTomorrowStart = new Date(tomorrowStart);
  dayAfterTomorrowStart.setDate(dayAfterTomorrowStart.getDate() + 1);

  return deadlineDate >= tomorrowStart && deadlineDate < dayAfterTomorrowStart;
};

const formatDueTime = (date) => {
  const hour24 = date.getHours();
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  const minute = String(date.getMinutes()).padStart(2, '0');
  const period = hour24 >= 12 ? 'PM' : 'AM';
  return `${hour12}:${minute} ${period}`;
};

const getUserTokenOrThrow = async (uid) => {
  const userDocRef = db.collection('users').doc(uid);
  const userDoc = await userDocRef.get();

  if (!userDoc.exists) {
    const error = new Error('User not found for provided uid');
    error.statusCode = 404;
    throw error;
  }

  const userData = userDoc.data() || {};
  const fcmToken = userData.fcmToken;

  if (!fcmToken || typeof fcmToken !== 'string') {
    const error = new Error('No valid fcmToken found for this user');
    error.statusCode = 400;
    throw error;
  }

  return fcmToken;
};

// Send push notification to a user by Firestore uid
router.post('/send-to-user', authMiddleware, async (req, res) => {
  try {
    const {
      uid,
      title,
      body,
      assignmentName,
      assignmentDeadline,
      data,
    } = req.body;

    if (!uid || !title || !assignmentDeadline) {
      return res.status(400).json({
        error: 'uid, title, and assignmentDeadline are required',
      });
    }

    const dueDate = parseDeadline(assignmentDeadline);
    if (!dueDate) {
      return res.status(400).json({
        error: 'assignmentDeadline must be a valid ISO datetime or epoch milliseconds',
      });
    }

    if (!isDueTomorrowLocal(dueDate)) {
      return res.status(409).json({
        error: 'Assignment is not due tomorrow in server local time; notification not sent',
        assignmentDeadline: dueDate.toISOString(),
      });
    }

    const resolvedBody =
      body ||
      (assignmentName
        ? `Your assignment "${String(assignmentName).trim()}" is due tomorrow at ${formatDueTime(dueDate)}.`
        : `You have an assignment due tomorrow at ${formatDueTime(dueDate)}.`);

    const fcmToken = await getUserTokenOrThrow(uid);

    const message = {
      token: fcmToken,
      notification: {
        title,
        body: resolvedBody,
      },
      data: stringifyData(data),
      android: {
        priority: 'high',
        notification: {
          channelId: 'assignment_deadline_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const messageId = await admin.messaging().send(message);

    return res.status(200).json({
      success: true,
      message: 'Notification sent successfully',
      messageId,
      uid,
      assignmentDeadline: dueDate.toISOString(),
    });
  } catch (error) {
    const code = error?.code || '';

    if (code === 'messaging/registration-token-not-registered') {
      const { uid } = req.body || {};
      if (uid) {
        await db.collection('users').doc(uid).set(
          {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmUpdatedAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
      }

      return res.status(410).json({
        error: 'FCM token is no longer valid. Token removed; client should refresh token.',
      });
    }

    console.error('Send notification error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to send notification',
    });
  }
});

// Send push only when the assignment document itself is due tomorrow
router.post('/send-due-tomorrow', authMiddleware, async (req, res) => {
  try {
    const { uid, assignmentId, title } = req.body;

    if (!uid || !assignmentId || !title) {
      return res.status(400).json({
        error: 'uid, assignmentId, and title are required',
      });
    }

    const assignmentDoc = await db.collection('assignments').doc(assignmentId).get();

    if (!assignmentDoc.exists) {
      return res.status(404).json({
        error: 'Assignment not found for provided assignmentId',
      });
    }

    const assignmentData = assignmentDoc.data() || {};
    if (assignmentData.userId !== uid) {
      return res.status(403).json({
        error: 'assignmentId does not belong to provided uid',
      });
    }

    if (assignmentData.completed === true) {
      return res.status(409).json({
        error: 'Assignment already completed; notification not sent',
      });
    }

    const dueDate = parseDeadline(assignmentData.deadline);
    if (!dueDate) {
      return res.status(400).json({
        error: 'Assignment deadline is missing or invalid',
      });
    }

    if (!isDueTomorrowLocal(dueDate)) {
      return res.status(409).json({
        error: 'Assignment is not due tomorrow in server local time; notification not sent',
        assignmentDeadline: dueDate.toISOString(),
      });
    }

    const fcmToken = await getUserTokenOrThrow(uid);
    const assignmentName = String(assignmentData.title || 'Assignment').trim();
    const body = `Your assignment "${assignmentName}" is due tomorrow at ${formatDueTime(dueDate)}.`;

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: stringifyData({
        assignmentId,
        assignmentName,
        deadline: dueDate.toISOString(),
      }),
      android: {
        priority: 'high',
        notification: {
          channelId: 'assignment_deadline_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const messageId = await admin.messaging().send(message);

    return res.status(200).json({
      success: true,
      message: 'Due-tomorrow notification sent successfully',
      messageId,
      uid,
      assignmentId,
      assignmentDeadline: dueDate.toISOString(),
    });
  } catch (error) {
    if (error?.statusCode) {
      return res.status(error.statusCode).json({ error: error.message });
    }

    const code = error?.code || '';
    if (code === 'messaging/registration-token-not-registered') {
      const { uid } = req.body || {};
      if (uid) {
        await db.collection('users').doc(uid).set(
          {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmUpdatedAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
      }

      return res.status(410).json({
        error: 'FCM token is no longer valid. Token removed; client should refresh token.',
      });
    }

    console.error('Send due-tomorrow notification error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to send due-tomorrow notification',
    });
  }
});

module.exports = router;
