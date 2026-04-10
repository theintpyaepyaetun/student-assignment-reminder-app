const cron = require('node-cron');
const { db, admin } = require('../config/firebase');

const getDateKey = (date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const parseDeadline = (rawDeadline) => {
  if (!rawDeadline) return null;

  if (typeof rawDeadline?.toDate === 'function') {
    return rawDeadline.toDate();
  }

  if (rawDeadline instanceof Date) {
    return rawDeadline;
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

const sendDueTomorrowBatch = async () => {
  const now = new Date();
  const todayKey = getDateKey(now);

  const snapshot = await db
    .collection('assignments')
    .where('completed', '==', false)
    .get();

  let sentCount = 0;
  let skippedCount = 0;

  for (const doc of snapshot.docs) {
    const assignment = doc.data() || {};
    const dueDate = parseDeadline(assignment.deadline);

    if (!dueDate || !isDueTomorrowLocal(dueDate, now)) {
      skippedCount += 1;
      continue;
    }

    const alreadySentDate = assignment?.notifications?.dueTomorrowLastSentOn;
    if (alreadySentDate === todayKey) {
      skippedCount += 1;
      continue;
    }

    const uid = assignment.userId;
    if (!uid) {
      skippedCount += 1;
      continue;
    }

    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      skippedCount += 1;
      continue;
    }

    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken || typeof fcmToken !== 'string') {
      skippedCount += 1;
      continue;
    }

    const assignmentName = String(assignment.title || 'Assignment').trim();
    const message = {
      token: fcmToken,
      notification: {
        title: 'Assignment Reminder',
        body: `Your assignment "${assignmentName}" is due tomorrow at ${formatDueTime(dueDate)}.`,
      },
      data: {
        assignmentId: String(doc.id),
        assignmentName,
        deadline: dueDate.toISOString(),
      },
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

    try {
      const messageId = await admin.messaging().send(message);

      await db.collection('assignments').doc(doc.id).set(
        {
          notifications: {
            dueTomorrowLastSentOn: todayKey,
            dueTomorrowSentAt: admin.firestore.Timestamp.now(),
            dueTomorrowMessageId: messageId,
          },
          updatedAt: admin.firestore.Timestamp.now(),
        },
        { merge: true }
      );

      sentCount += 1;
    } catch (error) {
      if (error?.code === 'messaging/registration-token-not-registered') {
        await db.collection('users').doc(uid).set(
          {
            fcmToken: admin.firestore.FieldValue.delete(),
            fcmUpdatedAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
          },
          { merge: true }
        );
      }
      skippedCount += 1;
    }
  }

  return { sentCount, skippedCount, total: snapshot.size };
};

const startDueTomorrowNotifier = () => {
  const enabled = String(process.env.DUE_TOMORROW_CRON_ENABLED || 'true').toLowerCase() === 'true';
  if (!enabled) {
    console.log('Due-tomorrow notifier disabled by DUE_TOMORROW_CRON_ENABLED=false');
    return;
  }

  const cronExpression = process.env.DUE_TOMORROW_CRON || '0 8 * * *';
  if (!cron.validate(cronExpression)) {
    console.error(`Invalid DUE_TOMORROW_CRON expression: ${cronExpression}`);
    return;
  }

  console.log(`Due-tomorrow notifier scheduled with cron: ${cronExpression}`);

  cron.schedule(cronExpression, async () => {
    try {
      const result = await sendDueTomorrowBatch();
      console.log(
        `Due-tomorrow notifier done: sent=${result.sentCount}, skipped=${result.skippedCount}, total=${result.total}`
      );
    } catch (error) {
      console.error('Due-tomorrow notifier failed:', error?.message || error);
    }
  });
};

module.exports = {
  startDueTomorrowNotifier,
  sendDueTomorrowBatch,
};
