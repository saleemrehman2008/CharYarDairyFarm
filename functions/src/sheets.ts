import {google, sheets_v4} from 'googleapis';
import {FieldValue, getFirestore, Timestamp} from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import {defineSecret, defineString} from 'firebase-functions/params';

/// The service-account JSON for the Sheets API, stored as a Functions secret:
///   firebase functions:secrets:set SHEETS_SA_KEY
export const sheetsKey = defineSecret('SHEETS_SA_KEY');

/// Fallback spreadsheet id, used when settings/farm has no sheetId:
///   firebase functions:config is not used — set SHEET_ID in .env or as a
///   deploy-time parameter.
export const sheetIdParam = defineString('SHEET_ID', {default: ''});

export type Tab =
  | 'Transactions'
  | 'Orders'
  | 'Partners'
  | 'MonthClose'
  | 'Udhaar'
  | 'Users'
  | 'Log';

/// Header row per tab, exactly as the handoff README lists it. The first column
/// is always the document id, which is what rows are upserted on.
export const HEADERS: Record<Tab, string[]> = {
  Transactions: [
    'id', 'date', 'month', 'type', 'party', 'category', 'qty', 'unit', 'rate',
    'amount', 'paid', 'paidAt', 'note', 'orderId', 'payVia', 'handledBy',
    'createdBy', 'createdAt', 'deleted',
  ],
  Orders: [
    'id', 'number', 'date', 'customer', 'items', 'total', 'mode', 'slot',
    'repeat', 'payment', 'status', 'approvedBy', 'deliveredAt',
  ],
  Partners: ['id', 'name', 'invested', 'reinvested', 'withdrawn', 'ratio%'],
  MonthClose: [
    'month', 'sales', 'purchases', 'expenses', 'AR', 'arIncluded',
    'profitShared',
    'partner1 share', 'partner2 share', 'partner3 share', 'partner4 share',
    'partner1 choice', 'partner2 choice', 'partner3 choice', 'partner4 choice',
    'closedBy', 'closedAt',
  ],
  Udhaar: [
    'uid', 'name', 'mobile', 'address', 'slot', 'litres', 'limit', 'balance',
    'status', 'approvedBy',
  ],
  Users: ['uid', 'name', 'email', 'role', 'status', 'createdAt'],
  Log: ['at', 'who', 'kind', 'what'],
};

let cachedClient: sheets_v4.Sheets | undefined;

function client(): sheets_v4.Sheets {
  if (cachedClient) return cachedClient;

  const raw = sheetsKey.value();
  if (!raw) throw new Error('SHEETS_SA_KEY secret is empty');

  const credentials = JSON.parse(raw) as {
    client_email: string;
    private_key: string;
  };

  const auth = new google.auth.JWT({
    email: credentials.client_email,
    // Secret managers often store the key with escaped newlines.
    key: credentials.private_key.replace(/\\n/g, '\n'),
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  });

  cachedClient = google.sheets({version: 'v4', auth});
  return cachedClient;
}

/// The spreadsheet to write to: settings/farm.sheetId wins, then SHEET_ID.
async function spreadsheetId(): Promise<string> {
  const snap = await getFirestore().doc('settings/farm').get();
  const fromDb = (snap.data()?.sheetId as string | undefined) ?? '';
  const id = fromDb || sheetIdParam.value();
  if (!id) throw new Error('No sheetId in settings/farm and no SHEET_ID set');
  return id;
}

const ensuredTabs = new Set<string>();

/// Creates the tab and writes its header row the first time it is touched.
async function ensureTab(id: string, tab: Tab): Promise<void> {
  const cacheKey = `${id}:${tab}`;
  if (ensuredTabs.has(cacheKey)) return;

  const api = client();
  const meta = await api.spreadsheets.get({spreadsheetId: id});
  const exists = (meta.data.sheets ?? []).some(
    (s) => s.properties?.title === tab,
  );

  if (!exists) {
    await api.spreadsheets.batchUpdate({
      spreadsheetId: id,
      requestBody: {
        requests: [{addSheet: {properties: {title: tab}}}],
      },
    });
  }

  const header = await api.spreadsheets.values.get({
    spreadsheetId: id,
    range: `${tab}!A1:Z1`,
  });
  if (!header.data.values?.length) {
    await api.spreadsheets.values.update({
      spreadsheetId: id,
      range: `${tab}!A1`,
      valueInputOption: 'RAW',
      requestBody: {values: [HEADERS[tab]]},
    });
  }

  ensuredTabs.add(cacheKey);
}

/// Writes one row, replacing the row whose first column already holds this id.
export async function upsertRow(
  tab: Tab,
  id: string,
  row: (string | number | boolean | null)[],
): Promise<void> {
  try {
    const sheetId = await spreadsheetId();
    await ensureTab(sheetId, tab);
    const api = client();

    const column = await api.spreadsheets.values.get({
      spreadsheetId: sheetId,
      range: `${tab}!A:A`,
    });
    const ids = (column.data.values ?? []).map((r) => `${r[0] ?? ''}`);
    const found = ids.indexOf(id);

    if (found >= 0) {
      // Sheet rows are 1-based and ids[0] is the header.
      await api.spreadsheets.values.update({
        spreadsheetId: sheetId,
        range: `${tab}!A${found + 1}`,
        valueInputOption: 'RAW',
        requestBody: {values: [row]},
      });
    } else {
      await api.spreadsheets.values.append({
        spreadsheetId: sheetId,
        range: `${tab}!A1`,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
        requestBody: {values: [row]},
      });
    }

    await markSync(true);
  } catch (err) {
    logger.error(`Sheets upsert failed for ${tab}/${id}`, err);
    await markSync(false);
    // Rethrowing lets the Functions runtime retry with backoff.
    throw err;
  }
}

/// Log lines only ever append — they are never edited.
export async function appendRow(
  tab: Tab,
  row: (string | number | boolean | null)[],
): Promise<void> {
  try {
    const sheetId = await spreadsheetId();
    await ensureTab(sheetId, tab);
    await client().spreadsheets.values.append({
      spreadsheetId: sheetId,
      range: `${tab}!A1`,
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {values: [row]},
    });
    await markSync(true);
  } catch (err) {
    logger.error(`Sheets append failed for ${tab}`, err);
    await markSync(false);
    throw err;
  }
}

/// Drives the "Sheets synced" / "Sync pending" tag in the app.
async function markSync(ok: boolean): Promise<void> {
  try {
    await getFirestore().doc('settings/farm').set(
      {
        syncOk: ok,
        ...(ok ? {lastSyncAt: FieldValue.serverTimestamp()} : {}),
      },
      {merge: true},
    );
  } catch (err) {
    logger.warn('Could not record sync status', err);
  }
}

/// Timestamps reach the sheet as plain `YYYY-MM-DD HH:mm` in Asia/Karachi.
export function stamp(value: unknown): string {
  if (!value) return '';
  const date =
    value instanceof Timestamp
      ? value.toDate()
      : value instanceof Date
        ? value
        : new Date(`${value}`);
  if (Number.isNaN(date.getTime())) return '';

  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Karachi',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
    .format(date)
    .replace(',', '');
}

/// Date only, for the `date` columns.
export function day(value: unknown): string {
  return stamp(value).slice(0, 10);
}
