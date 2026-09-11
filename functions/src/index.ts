import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import {setGlobalOptions} from 'firebase-functions/v2';
import {
  onDocumentCreated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';

import {notifyCofounders, notifyMasters, notifyUser, rs} from './notify';
import {appendRow, day, sheetsKey, stamp, upsertRow} from
  './sheets';

initializeApp();

setGlobalOptions({region: 'asia-south1', maxInstances: 10});

const db = () => getFirestore();

/// Every Sheets-writing trigger needs the service-account key. The sheet id is
/// a plain parameter, so it needs no declaration here.
const sheetOpts = {secrets: [sheetsKey]};

// ---------------------------------------------------------------------------
// Transactions -> Transactions tab
// ---------------------------------------------------------------------------

export const syncTransaction = onDocumentWritten(
  {document: 'transactions/{id}', ...sheetOpts},
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const t = after.data() ?? {};

    await upsertRow('Transactions', after.id, [
      after.id,
      day(t.date),
      `${t.monthId ?? ''}`,
      `${t.type ?? ''}`,
      `${t.party ?? ''}`,
      `${t.category ?? ''}`,
      t.qty ?? '',
      `${t.unit ?? ''}`,
      t.rate ?? '',
      Number(t.amount ?? 0),
      t.paid === true,
      stamp(t.paidAt),
      `${t.note ?? ''}`,
      `${t.orderId ?? ''}`,
      `${t.payVia ?? ''}`,
      `${t.handledBy ?? ''}`,
      `${t.createdBy ?? ''}`,
      stamp(t.createdAt),
      t.deletedAt ? 'deleted' : '',
    ]);
  },
);

// ---------------------------------------------------------------------------
// Orders -> Orders tab, plus the approval and delivery notifications
// ---------------------------------------------------------------------------

type OrderItem = {name?: string; qty?: number; unit?: string};

function itemsText(items: unknown): string {
  if (!items || typeof items !== 'object') return '';
  return Object.values(items as Record<string, OrderItem>)
    .map((i) => `${i.qty ?? ''} ${i.unit ?? ''} ${i.name ?? ''}`.trim())
    .join(', ');
}

export const syncOrder = onDocumentWritten(
  {document: 'orders/{id}', ...sheetOpts},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;

    const o = after.data() ?? {};
    const prev = before?.exists ? (before.data() ?? {}) : {};

    await upsertRow('Orders', after.id, [
      after.id,
      `${o.number ?? ''}`,
      day(o.createdAt),
      `${o.customerName ?? ''}`,
      itemsText(o.items),
      Number(o.total ?? 0),
      `${o.mode ?? ''}`,
      `${o.slot ?? ''}`,
      `${o.repeat ?? ''}`,
      `${o.pay ?? ''}`,
      `${o.status ?? ''}`,
      `${o.approvedByName ?? o.approvedBy ?? ''}`,
      stamp(o.deliveredAt),
    ]);

    // A brand new order: every co-founder hears about it.
    if (!before?.exists) {
      await notifyCofounders(
        'New order',
        `#${o.number} · ${o.customerName} · ${rs(o.total)}\n` +
          `${itemsText(o.items)}`,
        {type: 'order', orderId: after.id},
      );
      return;
    }

    const customerId = `${o.customerId ?? ''}`;

    if (!prev.approvedAt && o.approvedAt) {
      await Promise.all([
        notifyUser(
          customerId,
          'Order approved',
          `Order #${o.number} is approved and being prepared.`,
          {type: 'order', orderId: after.id},
        ),
        notifyCofounders(
          'Order approved',
          `#${o.number} approved by ${o.approvedByName ?? 'a co-founder'}.`,
          {type: 'order', orderId: after.id},
        ),
      ]);
    }

    if (prev.status !== o.status) {
      const line: Record<string, string> = {
        out: `Order #${o.number} is out for delivery.`,
        delivered: `Order #${o.number} is delivered. Thank you!`,
      };
      const body = line[`${o.status}`];
      if (body) {
        await notifyUser(customerId, 'Char Yar Dairy Farm', body, {
          type: 'order',
          orderId: after.id,
        });
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Partners -> Partners tab. Ratios shift whenever any partner's capital
// changes, so every row is rewritten together.
// ---------------------------------------------------------------------------

export const syncPartners = onDocumentWritten(
  {document: 'partners/{id}', ...sheetOpts},
  async (event) => {
    const snap = await db().collection('partners').orderBy('createdAt').get();
    const capital = snap.docs.map(
      (d) => Number(d.data().invested ?? 0) + Number(d.data().reinvested ?? 0),
    );
    const total = capital.reduce((a, b) => a + b, 0);

    for (const [i, doc] of snap.docs.entries()) {
      const p = doc.data();
      const ratio = total > 0 ? (capital[i] / total) * 100 : 0;
      await upsertRow('Partners', doc.id, [
        doc.id,
        `${p.name ?? ''}`,
        Number(p.invested ?? 0),
        Number(p.reinvested ?? 0),
        Number(p.withdrawn ?? 0),
        Math.round(ratio * 10) / 10,
      ]);
    }

    // Only an added investment is worth a notification; a month close sends its
    // own message.
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before?.exists || !after?.exists) return;

    const added =
      Number(after.data()?.invested ?? 0) -
      Number(before.data()?.invested ?? 0);
    if (added > 0) {
      await notifyCofounders(
        'Investment added',
        `${after.data()?.name}: ${rs(added)}. Share ratios have moved.`,
        {type: 'investment'},
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Months -> MonthClose tab
// ---------------------------------------------------------------------------

type Share = {share?: number; choice?: string; name?: string};

export const syncMonthClose = onDocumentWritten(
  {document: 'months/{id}', ...sheetOpts},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;

    const m = after.data() ?? {};
    if (m.status !== 'closed') return;

    const shares = (m.shares as Share[] | undefined) ?? [];
    const slot = (i: number, key: 'share' | 'choice') =>
      shares[i] ? (shares[i][key] ?? '') : '';

    await upsertRow('MonthClose', after.id, [
      after.id,
      Number(m.sales ?? 0),
      Number(m.purchases ?? 0),
      Number(m.expenses ?? 0),
      Number(m.receivables ?? 0),
      m.arIncluded === true,
      Number(m.profitShared ?? m.profit ?? 0),
      slot(0, 'share'),
      slot(1, 'share'),
      slot(2, 'share'),
      slot(3, 'share'),
      slot(0, 'choice'),
      slot(1, 'choice'),
      slot(2, 'choice'),
      slot(3, 'choice'),
      `${m.closedByName ?? m.closedBy ?? ''}`,
      stamp(m.closedAt),
    ]);

    // Notify once, on the close itself.
    if (before?.exists && before.data()?.status !== 'closed') {
      await notifyCofounders(
        'Month closed',
        `${after.id}: ${rs(m.profitShared ?? m.profit)} shared out.`,
        {type: 'monthClose', monthId: after.id},
      );

      // Each udhaar customer gets their bill for the month.
      const accounts = await db()
        .collection('udhaar_accounts')
        .where('status', '==', 'approved')
        .get();
      await Promise.all(
        accounts.docs
          .filter((d) => Number(d.data().balance ?? 0) > 0)
          .map((d) =>
            notifyUser(
              d.id,
              'Your monthly bill',
              `${rs(d.data().balance)} is due for ${after.id}.`,
              {type: 'udhaarBill'},
            ),
          ),
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Udhaar accounts -> Udhaar tab
// ---------------------------------------------------------------------------

export const syncUdhaar = onDocumentWritten(
  {document: 'udhaar_accounts/{uid}', ...sheetOpts},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;

    const u = after.data() ?? {};
    await upsertRow('Udhaar', after.id, [
      after.id,
      `${u.name ?? ''}`,
      `${u.mobile ?? ''}`,
      `${u.address ?? ''}`,
      `${u.slot ?? ''}`,
      Number(u.litresPerDay ?? 0),
      Number(u.limit ?? 0),
      Number(u.balance ?? 0),
      `${u.status ?? ''}`,
      `${u.approvedByName ?? u.approvedBy ?? ''}`,
    ]);

    if (!before?.exists) {
      await notifyCofounders(
        'New udhaar registration',
        `${u.name} · ${u.litresPerDay} L/day · suggested limit ` +
          `${rs(u.limit)}`,
        {type: 'udhaar', uid: after.id},
      );
      return;
    }

    if (before.data()?.status !== 'approved' && u.status === 'approved') {
      await notifyUser(
        after.id,
        'Udhaar approved',
        `You can now buy on monthly credit, up to ${rs(u.limit)}.`,
        {type: 'udhaar'},
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Users -> Users tab
// ---------------------------------------------------------------------------

export const syncUser = onDocumentWritten(
  {document: 'users/{uid}', ...sheetOpts},
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!after?.exists) return;

    const u = after.data() ?? {};
    await upsertRow('Users', after.id, [
      after.id,
      `${u.name ?? ''}`,
      `${u.email ?? ''}`,
      `${u.role ?? ''}`,
      `${u.status ?? ''}`,
      stamp(u.createdAt),
    ]);

    if (!before?.exists) {
      await notifyMasters(
        'New sign-up',
        `${u.name} (${u.email}) is waiting for approval.`,
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Activity log -> Log tab (append only)
// ---------------------------------------------------------------------------

export const syncLog = onDocumentCreated(
  {document: 'logs/{id}', ...sheetOpts},
  async (event) => {
    const l = event.data?.data();
    if (!l) return;
    await appendRow('Log', [
      stamp(l.at),
      `${l.who ?? ''}`,
      `${l.kind ?? ''}`,
      `${l.what ?? ''}`,
    ]);
  },
);

// ---------------------------------------------------------------------------
// Daily orders from standing subscriptions, 04:00 Asia/Karachi
// ---------------------------------------------------------------------------

export const raiseDailyOrders = onSchedule(
  {schedule: '0 4 * * *', timeZone: 'Asia/Karachi'},
  async () => {
    const subs = await db()
      .collection('subscriptions')
      .where('active', '==', true)
      .get();
    if (subs.empty) return;

    const settings = db().doc('settings/farm');

    for (const sub of subs.docs) {
      const s = sub.data();
      try {
        // Keep the order numbers in the same sequence the app uses.
        const number = await db().runTransaction(async (tx) => {
          const snap = await tx.get(settings);
          const next = Number(snap.data()?.orderSeq ?? 1000) + 1;
          tx.set(settings, {orderSeq: next}, {merge: true});
          return `${next}`;
        });

        await db().collection('orders').add({
          number,
          customerId: s.customerId,
          customerName: s.customerName ?? '',
          items: s.items ?? {},
          total: Number(s.total ?? 0),
          mode: s.mode ?? 'delivery',
          slot: s.slot ?? 'morning',
          repeat: 'daily',
          pay: s.pay ?? 'cod',
          status: 'new',
          subscriptionId: sub.id,
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logger.error(`Could not raise the daily order for ${sub.id}`, err);
      }
    }

    logger.info(`Raised ${subs.size} daily orders`);
  },
);
