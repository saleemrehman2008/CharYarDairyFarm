import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

export const COFOUNDER_TOPIC = 'cofounders';

/// Everything the farm side should know about goes to one topic, which the app
/// subscribes master and co-founder devices to on sign-in.
export async function notifyCofounders(
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  try {
    await admin.messaging().send({
      topic: COFOUNDER_TOPIC,
      notification: {title, body},
      data,
      android: {priority: 'high'},
    });
  } catch (err) {
    logger.warn('Could not notify co-founders', err);
  }
}

/// One customer, on every device they have signed in on.
export async function notifyUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  if (!uid) return;
  try {
    const snap = await admin.firestore().doc(`users/${uid}`).get();
    const tokens = (snap.data()?.fcmTokens as string[] | undefined) ?? [];
    if (!tokens.length) return;

    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data,
      android: {priority: 'high'},
    });

    // Drop tokens the device no longer honours, so the list stays useful.
    const dead = res.responses
      .map((r, i) => (r.success ? null : tokens[i]))
      .filter((t): t is string => t !== null);
    if (dead.length) {
      await snap.ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
      });
    }
  } catch (err) {
    logger.warn(`Could not notify ${uid}`, err);
  }
}

/// The master accounts, for sign-up alerts.
export async function notifyMasters(
  title: string,
  body: string,
): Promise<void> {
  try {
    const masters = await admin
      .firestore()
      .collection('users')
      .where('role', '==', 'master')
      .get();
    await Promise.all(
      masters.docs.map((d) => notifyUser(d.id, title, body)),
    );
  } catch (err) {
    logger.warn('Could not notify masters', err);
  }
}

/// `Rs 1,23,456`, the way the app shows money.
export function rs(value: unknown): string {
  const n = Math.round(Number(value ?? 0));
  const neg = n < 0;
  const whole = `${Math.abs(n)}`;
  if (whole.length <= 3) return `Rs ${neg ? '-' : ''}${whole}`;

  const tail = whole.slice(-3);
  let head = whole.slice(0, -3);
  const parts: string[] = [];
  while (head.length > 2) {
    parts.unshift(head.slice(-2));
    head = head.slice(0, -2);
  }
  if (head) parts.unshift(head);
  return `Rs ${neg ? '-' : ''}${parts.join(',')},${tail}`;
}
