import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

function calculateNextRun(from: Date, frequency: string): Date {
  const f = frequency.toLowerCase();
  switch (f) {
    case "daily":
      return new Date(from.getTime() + 24 * 60 * 60 * 1000);
    case "weekly":
      return new Date(from.getTime() + 7 * 24 * 60 * 60 * 1000);
    case "monthly": {
      const year = from.getFullYear();
      const month = from.getMonth();
      const day = from.getDate();
      const nextMonth = new Date(year, month + 1, day);
      if (nextMonth.getDate() !== day) {
        return new Date(year, month + 2, 0);
      }
      return nextMonth;
    }
    case "yearly":
      return new Date(from.getFullYear() + 1, from.getMonth(), from.getDate());
    default:
      return new Date(from.getTime() + 24 * 60 * 60 * 1000);
  }
}

export const processScheduledExpenses = functions.pubsub
  .schedule("every 15 minutes")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const usersSnap = await db.collection("users").get();

    const batch = db.batch();
    let updatedCount = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;

      const schedulesSnap = await db
        .collection("users")
        .doc(uid)
        .collection("schedules")
        .where("isActive", "==", true)
        .where("nextRun", "<=", now)
        .get();

      for (const scheduleDoc of schedulesSnap.docs) {
        const data = scheduleDoc.data() as any;
        const frequency = (data.frequency || "one-time")
          .toString()
          .toLowerCase();

        const scheduleRef = scheduleDoc.ref;

        if (frequency === "one-time" || frequency === "one time") {
          batch.update(scheduleRef, {
            isActive: false,
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastProcessed: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          const lastProcessedTs =
            (data.lastProcessed as admin.firestore.Timestamp | undefined) ||
            now;
          const lastProcessedDate = lastProcessedTs.toDate();
          const nextRunDate = calculateNextRun(lastProcessedDate, frequency);

          batch.update(scheduleRef, {
            isActive: true,
            status: "active",
            nextRun: admin.firestore.Timestamp.fromDate(nextRunDate),
            lastProcessed: admin.firestore.FieldValue.serverTimestamp(),
            occurrenceCount: admin.firestore.FieldValue.increment(1),
          });
        }

        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    console.log(`Processed ${updatedCount} due schedules`);
    return null;
  });