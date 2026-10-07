/**
 * WalkQuest 3D Cloud Functions (2nd gen).
 *
 *  - onSessionCreated: anti-cheat sanity checks + guild progress.
 *  - weeklyReset:      zero weekly step counters every Monday 00:00 UTC.
 *  - onChallengeAccepted: notify the challenger (stub for FCM).
 */
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Humans don't sustain > 25 km/h on foot, or > 2.2 steps per meter.
const MAX_SPEED_KMH = 25;
const MAX_STEPS_PER_M = 2.2;
const MIN_STEPS_PER_M = 0.4;

exports.onSessionCreated = onDocumentCreated("users/{uid}/sessions/{sessionId}", async (event) => {
  const s = event.data?.data();
  if (!s) return;
  const { uid } = event.params;

  const hours = (s.activeSeconds || 0) / 3600;
  const speed = hours > 0 ? s.distanceM / 1000 / hours : 0;
  const stepsPerM = s.distanceM > 50 ? s.steps / s.distanceM : 1;

  const reasons = [];
  if (speed > MAX_SPEED_KMH) reasons.push(`speed ${speed.toFixed(1)} km/h`);
  if (stepsPerM > MAX_STEPS_PER_M) reasons.push(`too many steps (${stepsPerM.toFixed(2)}/m)`);
  if (s.distanceM > 500 && stepsPerM < MIN_STEPS_PER_M) reasons.push(`too few steps (${stepsPerM.toFixed(2)}/m)`);

  const userRef = db.doc(`users/${uid}`);

  if (reasons.length) {
    logger.warn("Flagged session", { uid, sessionId: event.params.sessionId, reasons });
    // Claw back the rewards the client granted for this session.
    await db.runTransaction(async (tx) => {
      const user = await tx.get(userRef);
      if (!user.exists) return;
      const u = user.data();
      tx.update(userRef, {
        coins: Math.max(0, (u.coins || 0) - (s.coinsEarned || 0)),
        xp: Math.max(0, (u.xp || 0) - (s.xpEarned || 0)),
        weeklySteps: Math.max(0, (u.weeklySteps || 0) - (s.steps || 0)),
      });
      tx.update(event.data.ref, { flagged: true, flagReasons: reasons });
    });
    return;
  }

  // Credit the weekly goal of every guild the player belongs to.
  const guilds = await db.collection("guilds").where("memberUids", "array-contains", uid).get();
  const batch = db.batch();
  guilds.forEach((g) => {
    batch.update(g.ref, { progressSteps: admin.firestore.FieldValue.increment(s.steps || 0) });
  });
  await batch.commit();
});

exports.weeklyReset = onSchedule({ schedule: "0 0 * * 1", timeZone: "Etc/UTC" }, async () => {
  const users = await db.collection("users").where("weeklySteps", ">", 0).get();
  let batch = db.batch();
  let n = 0;
  for (const doc of users.docs) {
    batch.update(doc.ref, { weeklySteps: 0 });
    if (++n % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();

  const guilds = await db.collection("guilds").get();
  batch = db.batch();
  guilds.forEach((g) => batch.update(g.ref, { progressSteps: 0 }));
  await batch.commit();
  logger.info(`Weekly reset: ${n} users, ${guilds.size} guilds`);
});

exports.onChallengeAccepted = onDocumentUpdated("challenges/{id}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status || after.status !== "accepted") return;
  // Hook up FCM here: look up the challenger's device tokens and send
  // `${after.toName} accepted your challenge!`.
  logger.info("Challenge accepted", { id: event.params.id, from: after.fromUid, to: after.toUid });
});
